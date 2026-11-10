"""Exercise the Responses boundary and real SML repair entirely offline."""
import io
import json
import os
from pathlib import Path
import sys
import tempfile
import urllib.error
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
import model
import run
import benchmark
from compiler_checks import BAD, GOOD


MODEL = {"name": "gpt-6-luna", "provider": "openai", "reasoning_effort": "medium"}
KEY = "sk-offline-api-check-not-a-real-key"
PROVIDERS = {
    "openai": {"label": "GPT-Luna", "model": MODEL, "key": KEY,
               "key_env": "OPENAI_API_KEY", "url": "https://api.openai.com/v1/responses"},
    "deepseek": {"label": "DeepSeek-1017", "model": {
        "name": "deepseek-flash", "provider": "deepseek", "reasoning_effort": "high"},
        "key": "sk-offline-deepseek-check-not-a-real-key", "key_env": "DEEPSEEK_API_KEY",
        "url": "https://api.deepseek.com/responses"},
}
REASONING = "This reasoning summary must never become the repaired assistant answer."
USAGE = {"input_tokens": 3000, "input_tokens_details": {"cached_tokens": 1024},
         "output_tokens": 900, "output_tokens_details": {"reasoning_tokens": 700},
         "total_tokens": 3900}


def predicates(ensures=GOOD):
    return {"status": "ok", "requires_expr": "true", "ensures_expr": ensures, "reason": ""}


def response(value=None, selected=MODEL):
    value = predicates() if value is None else value
    return {"id": "resp_offline", "object": "response", "model": selected["name"],
            "status": "completed", "error": None, "incomplete_details": None,
            "output": [
                {"id": "rs_offline", "type": "reasoning",
                 "summary": [{"type": "summary_text", "text": REASONING}]},
                {"id": "msg_offline", "type": "message", "role": "assistant",
                 "status": "completed", "content": [
                     {"type": "output_text", "text": json.dumps(value), "annotations": []}]}],
            "usage": USAGE}


def capture_http(outcomes, calls, provider="openai"):
    pending = iter(outcomes)
    backend = PROVIDERS[provider]

    def urlopen(request, timeout):
        assert request.full_url == backend["url"], request.full_url
        assert request.get_method() == "POST"
        assert request.get_header("Authorization") == "Bearer " + backend["key"]
        payload = json.loads(request.data)
        assert all(item["key"] not in json.dumps(payload) for item in PROVIDERS.values())
        calls.append({"payload": payload, "timeout": timeout})
        try:
            outcome = next(pending)
        except StopIteration:
            raise AssertionError("Unexpected additional API request") from None
        if isinstance(outcome, BaseException):
            raise outcome
        response_body = io.BytesIO(outcome.encode("utf-8"))
        response_body.status = 200
        return response_body

    return urlopen


def call(config, outcome):
    calls = []
    with patch("urllib.request.urlopen", side_effect=capture_http([outcome], calls, config["provider"])):
        record, parsed = model.call_model(
            [{"role": "system", "content": "Return the contract as JSON."},
             {"role": "user", "content": "Remove every occurrence of x."}], config)
    assert len(calls) == 1
    assert all(item["key"] not in json.dumps(record) for item in PROVIDERS.values())
    return record, parsed, calls[0]


def boundary_checks(config):
    backend = PROVIDERS[config["provider"]]
    selected = backend["model"]
    raw = json.dumps(response(selected=selected), indent=1)
    record, parsed, captured = call(config, raw)
    assert record["status"] == "ok" and parsed == predicates(), record
    success_record = record
    assert record["raw_response"] == raw
    assert record["api"]["usage"] == USAGE
    assert record["api"]["provider"] == config["provider"]
    assert record["api"]["model"] == selected["name"]
    measured = record["backend_metrics"]
    assert (measured["prompt_eval_count"], measured["eval_count"],
            measured["prompt_eval_cached_count"], measured["reasoning_tokens"]) == (3000, 900, 1024, 700)
    assert all(measured[name] is None for name in
               ("load_duration", "prompt_eval_duration", "eval_duration", "total_duration"))
    payload = captured["payload"]
    assert captured["timeout"] == config["http_timeout"]
    assert payload["model"] == selected["name"]
    assert payload["max_output_tokens"] == 8192
    assert payload["reasoning"]["effort"] == selected["reasoning_effort"]
    assert not {"seed", "options", "think", "keep_alive", "temperature", "top_p",
                "top_k", "min_p", "num_ctx", "num_predict", "response_format"}.intersection(payload)
    schema_format = payload["text"]["format"]
    assert schema_format["type"] == "json_schema"
    if config["provider"] == "openai":
        assert schema_format["strict"] is True and payload["store"] is False
    else:
        # DeepSeek's documented Responses format omits strict; responses are stateless.
        assert set(schema_format) == {"type", "name", "schema"} and "store" not in payload
    schema = schema_format["schema"]
    fields = {"status", "requires_expr", "ensures_expr", "reason"}
    assert schema["type"] == "object" and schema["additionalProperties"] is False
    assert set(schema["required"]) == set(schema["properties"]) == fields
    assert set(schema["properties"]["status"]["enum"]) == {"ok", "ambiguous", "unsupported"}
    for name in ("requires_expr", "ensures_expr"):
        assert set(schema["properties"][name]["type"]) == {"string", "null"}

    incomplete = response(selected=selected)
    incomplete.update(status="incomplete", incomplete_details={"reason": "max_output_tokens"})
    record, parsed, _ = call(config, json.dumps(incomplete))
    assert record["status"] == "invalid_model_output" and parsed is None
    assert record["done_reason"] == "length" and record["backend_metrics"]["eval_count"] == 900
    assert record["api"]["incomplete_details"] == {"reason": "max_output_tokens"}

    refused = response(selected=selected)
    refused["output"][-1]["content"] = [{"type": "refusal", "refusal": "Offline refusal."}]
    record, parsed, _ = call(config, json.dumps(refused))
    assert record["status"] == "invalid_model_output" and parsed is None
    assert record["done_reason"] == "refusal"

    for status in ("failed", "cancelled"):
        failed = response(selected=selected)
        failed.update(status=status, error={"code": "server_error", "message": "Offline failure."})
        record, parsed, _ = call(config, json.dumps(failed))
        assert record["status"] == "model_error" and parsed is None
        assert record["api"]["status"] == status

    for value in ({}, [], {"status": "unknown"}, {**predicates(), "ensures_expr": None},
                  {**predicates(), "requires_expr": 7}, {"status": "ok", "requires_expr": "true"}):
        record, parsed, _ = call(config, json.dumps(response(value, selected)))
        assert record["status"] == "invalid_model_output" and parsed is None
    for value in ({**predicates(), "extra": True, "reason": "Explanation is allowed."},
                  {"status": "ok", "requires_expr": "true", "ensures_expr": GOOD},
                  {"status": "ok", "requires_expr": "", "ensures_expr": ""}):
        record, parsed, _ = call(config, json.dumps(response(value, selected)))
        assert record["status"] == "ok" and parsed == value
    malformed = response(selected=selected)
    malformed["output"][-1]["content"][0]["text"] = "not JSON"
    record, parsed, _ = call(config, json.dumps(malformed))
    assert record["status"] == "invalid_model_output" and parsed is None
    for status in ("ambiguous", "unsupported"):
        for value in ({"status": status}, {"status": status, "requires_expr": "true",
                       "ensures_expr": None, "reason": ""}):
            record, parsed, _ = call(config, json.dumps(response(value, selected)))
            assert record["status"] == status and parsed == value

    for code, kind in ((401, "invalid_api_key"), (402, "insufficient_balance"), (429, "rate_limit_exceeded")):
        # A server may echo a credential in an error. Preserve the diagnosis, not the secret.
        body = json.dumps({"error": {"message": "Offline error for " + backend["key"], "code": kind}})
        error = urllib.error.HTTPError(backend["url"], code,
                                      "Offline HTTP error", {}, io.BytesIO(body.encode()))
        record, parsed, _ = call(config, error)
        assert record["status"] == "model_error" and parsed is None
        assert record["api"]["http_status"] == code
        assert kind in record["raw_response"] and "Offline error" in record["raw_response"]
        assert not record["http_timeout"]

    record, parsed, _ = call(config, urllib.error.URLError(TimeoutError("Offline timeout")))
    assert record["status"] == "model_error" and record["http_timeout"] and parsed is None
    with patch.dict(os.environ, {backend["key_env"]: ""}), patch("urllib.request.urlopen") as transport:
        record, parsed = model.call_model([], config)
    transport.assert_not_called()
    assert record["status"] == "model_error" and parsed is None
    unrelated_keys = {item["key_env"]: "" for name, item in PROVIDERS.items() if name != config["provider"]}
    with patch.dict(os.environ, unrelated_keys):
        record, parsed, _ = call(config, raw)
    assert record["status"] == "ok" and parsed == predicates()
    return success_record


def summary_check(config, successful_request):
    backend = PROVIDERS[config["provider"]]
    label = backend["label"]
    records = [{"case_id": "hw_remove", "model_label": label, "topic": "lists",
                "version": "original", "expected_status": "ok",
                "status": "faithful", "semantic": {"status": "passed_semantic_checks"},
                "execution": {"status": "passed_sampled_tests", "preparation": {
                    "mode": "model", "attempts": [successful_request, successful_request]}}},
               {"case_id": "hw_remove", "model_label": label, "topic": "lists", "status": "not_run",
                "version": "original", "expected_status": "ok"}]
    summary = benchmark.summarize(records, {"models": {label: backend["model"]},
        "versions": ["original"], "case_ids": ["hw_remove"]})
    scored = summary["models"][label]
    assert scored["denominator"] == 2 and not scored["complete"]
    assert scored["final_translation_faithful"] == {"count": 1, "rate": 0.5}
    requests = scored["requests"]
    assert requests["count"] == 2
    metrics = requests["backend"]
    assert metrics["prompt_eval_count"] == 6000 and metrics["prompt_eval_cached_count"] == 2048
    assert metrics["eval_count"] == 1800 and metrics["reasoning_tokens"] == 1400
    assert metrics["total_seconds"] is None and metrics["tokens_per_second"] is None


def repair_check(output, config, node):
    calls = []
    backend = PROVIDERS[config["provider"]]
    raw = [json.dumps(response(predicates(ensures), backend["model"])) for ensures in (BAD, GOOD)]
    with patch("urllib.request.urlopen", side_effect=capture_http(raw, calls, config["provider"])):
        result = run.run_case(node, output / "repair", config, helpers=(), dependencies=(),
                              property_source="model", role="Candidate")
    assert len(calls) == 2
    attempts = result["preparation"]["attempts"]
    assert [item["compile"]["status"] for item in attempts] == ["compile_error", "compiled"]
    assert [item["raw_response"] for item in attempts] == raw
    assert result["status"] == "passed_sampled_tests", result
    assert result["pbt"]["accepted"] >= config["valid_target"]
    repair_input = calls[1]["payload"]["input"]
    assert repair_input[:-2] == calls[0]["payload"]["input"]
    assert repair_input[-2]["role"] == "assistant"
    assert json.loads(repair_input[-2]["content"]) == predicates(BAD)
    assert REASONING not in json.dumps(repair_input)
    assert "predicate_compile_diagnostics" in repair_input[-1]["content"]
    assert "predicate.cm:" in repair_input[-1]["content"]
    run.dump(output / "repair" / "result.json", result)
    checkpoint = json.loads((output / "repair" / "translation.json").read_text())
    assert [item["compile"]["status"] for item in checkpoint["attempts"]] == ["compile_error", "compiled"]
    assert all(item["key"] not in json.dumps(result) + json.dumps(checkpoint) for item in PROVIDERS.values())


def main():
    original, _, plan = run.load_plan(case_id="hw_remove", property_source="model")
    before = json.dumps(original, sort_keys=True)
    (ROOT / "runs").mkdir(exist_ok=True)
    output = Path(tempfile.mkdtemp(prefix="api-checks-", dir=ROOT / "runs"))
    (output / "MOCK_ONLY.txt").write_text("HTTP was stubbed; no API requests or charges. SML compilation and PBT were real.\n")
    with patch.dict(os.environ, {item["key_env"]: item["key"] for item in PROVIDERS.values()}), patch(
            "urllib.request.urlopen", side_effect=AssertionError("API checks must stay offline")):
        for provider, backend in PROVIDERS.items():
            config = model.configure(original, backend["model"], seed=15001)
            assert json.dumps(original, sort_keys=True) == before, "configure mutated the base configuration"
            assert config["provider"] == provider and "think" not in config
            assert "seed" not in config["model_options"]
            assert config["seed"] == original["seed"]  # PBT seed remains independent of the model API.
            defaulted = model.configure(original, {key: backend["model"][key] for key in ("provider", "name")})
            assert defaulted["reasoning_effort"] == backend["model"]["reasoning_effort"]
            successful_request = boundary_checks(config)
            summary_check(config, successful_request)
            (output / provider).mkdir()
            repair_check(output / provider, config, plan["nodes"]["hw_remove"])
    summary = {"status": "passed", "checks": ["responses_wire_contract", "reasoning_before_message",
        "usage_without_double_counting", "incomplete_and_refusal", "response_parsing",
        "http_errors_and_key_redaction", "timeout_and_missing_key",
        "summary_usage_and_fixed_denominator", "real_compile_repair_and_pbt"],
        "providers": list(PROVIDERS), "model_calls": 0,
        "compiled_case": "hw_remove", "valid_target": original["valid_target"]}
    run.dump(output / "summary.json", summary)
    print(json.dumps({"summary": str(output / "summary.json"), **summary}, indent=2))


if __name__ == "__main__":
    main()

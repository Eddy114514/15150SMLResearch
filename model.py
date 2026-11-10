"""Prompt assembly and one model HTTP/JSON request."""

import http.client
import json
import os
import time
import urllib.error
import urllib.request

import corpus

RESPONSES_PROVIDERS = {
    "openai": {"base_url": "https://api.openai.com/v1", "key_env": "OPENAI_API_KEY",
               "default_effort": "medium"},
    "deepseek": {"base_url": "https://api.deepseek.com", "key_env": "DEEPSEEK_API_KEY",
                 "default_effort": "high"},
}

SCHEMA = {
    "type": "object", "additionalProperties": False,
    "properties": {
        "status": {"type": "string", "enum": ["ok", "ambiguous", "unsupported"]},
        "requires_expr": {"type": ["string", "null"]},
        "ensures_expr": {"type": ["string", "null"]},
        "reason": {"type": "string"}},
    "required": ["status", "requires_expr", "ensures_expr", "reason"]}


def build_task_data(case, contract, helpers=()):
    """Keep implementation and research data out of the translation request."""
    target = {key: case[key] for key in corpus.FIELDS}
    target["contract"] = contract
    # Only public task context enters the request. Labels, manual predicates,
    # readiness findings and source implementations remain outside this list.
    benchmark = case.get("benchmark", {})
    # The selected contract is the sole specification. Supplying another
    # version alongside it would silently repair ambiguous benchmark inputs.
    for key in ("observation", "budgets"):
        if key in benchmark:
            target[key] = benchmark[key]
    return {"target": target, "helpers": [
        {key: helper[key] for key in
         ("case_id", "callable_name", "signature", "contract", "status")}
        for helper in helpers]}


def initial_messages(task_data, translate_prompt):
    return [{"role": "system", "content": translate_prompt},
            {"role": "user", "content": json.dumps(task_data, ensure_ascii=False)}]


def repair_messages(messages, first_json, diagnostics, repair_prompt):
    data = {"predicate_compile_diagnostics": {"stdout": diagnostics, "stderr": ""}}
    return messages + [
        {"role": "assistant", "content": first_json},
        {"role": "user", "content": repair_prompt + "\n\n" + json.dumps(data, ensure_ascii=False)},
    ]


def extract_metrics(envelope):
    """Keep the backend's original nanosecond durations and token counters."""
    durations = ("load_duration", "prompt_eval_duration", "eval_duration", "total_duration")
    counts = ("prompt_eval_count", "eval_count", "prompt_eval_cached_count")
    return {key: envelope.get(key) for key in durations + counts}


def configure(config, selected, seed=None):
    """Select one benchmark model without mutating the shared configuration."""
    provider = selected.get("provider", "ollama")
    configured = {**config, "model": selected["name"], "provider": provider,
                  "model_options": dict(config["model_options"])}
    if provider == "ollama":
        configured["think"] = selected.get("think")
        configured.pop("reasoning_effort", None)
        if seed is not None:
            configured["model_options"]["seed"] = seed
    elif provider in RESPONSES_PROVIDERS:
        configured["reasoning_effort"] = selected.get(
            "reasoning_effort", RESPONSES_PROVIDERS[provider]["default_effort"])
        configured.pop("think", None)
        configured["model_options"].pop("seed", None)
    else:
        raise ValueError(f"Unknown model provider: {provider}")
    return configured


def _response_record(provider):
    result = {"status": None, "raw_response": None, "exception": None,
              "done_reason": None, "elapsed_seconds": 0.0, "http_timeout": False,
              "backend_metrics": extract_metrics({})}
    if provider in RESPONSES_PROVIDERS:
        result["api"] = {"provider": provider, "http_status": None}
    return result


def _responses_content(envelope, result):
    provider = result["api"]["provider"]
    result["api"].update({key: envelope.get(key) for key in
                          ("id", "model", "status", "usage", "error", "incomplete_details")})
    usage = envelope.get("usage") or {}
    result["backend_metrics"].update(
        prompt_eval_count=usage.get("input_tokens"), eval_count=usage.get("output_tokens"),
        prompt_eval_cached_count=(usage.get("input_tokens_details") or {}).get("cached_tokens"),
        reasoning_tokens=(usage.get("output_tokens_details") or {}).get("reasoning_tokens"))
    status = envelope.get("status")
    result["done_reason"] = status
    if status in ("failed", "cancelled") or envelope.get("error"):
        raise RuntimeError(f"{provider} response {status}: {envelope.get('error')}")
    if status == "incomplete":
        reason = (envelope.get("incomplete_details") or {}).get("reason")
        result["done_reason"] = "length" if reason == "max_output_tokens" else reason
        raise ValueError(f"{provider} response incomplete: {reason}")
    if status != "completed":
        raise ValueError(f"{provider} response did not complete: {status}")
    text = []
    for item in envelope["output"]:
        if item.get("type") != "message":
            continue
        for part in item["content"]:
            if part.get("type") == "refusal":
                result["done_reason"] = "refusal"
                raise ValueError(f"{provider} refusal: {part.get('refusal', '')}")
            if part.get("type") == "output_text":
                text.append(part["text"])
    return "".join(text)


def _request(request, timeout, provider, api_key=None):
    result = _response_record(provider)
    predicates = None
    started = time.monotonic()
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            result["raw_response"] = response.read().decode("utf-8")
            if provider in RESPONSES_PROVIDERS:
                result["api"]["http_status"] = response.status
        envelope = json.loads(result["raw_response"])
        if provider in RESPONSES_PROVIDERS:
            content = _responses_content(envelope, result)
        else:
            result["backend_metrics"] = extract_metrics(envelope)
            result["done_reason"] = envelope.get("done_reason")
            if result["done_reason"] == "length":
                raise ValueError("model output budget exhausted")
            if envelope["done"] is not True:
                raise ValueError("model response did not finish (done is not true)")
            content = envelope["message"]["content"]
        value = json.loads(content)
        if value["status"] not in ("ok", "ambiguous", "unsupported"):
            raise ValueError("unknown model status")
        if value["status"] == "ok" and any(not isinstance(value[key], str)
                for key in ("requires_expr", "ensures_expr")):
            raise ValueError("ok requires predicate strings")
        predicates = value
        result["status"] = predicates["status"]
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        result["raw_response"] = body.replace(api_key, "[REDACTED]") if api_key else body
        result["status"] = "model_error"
        result["exception"] = f"HTTP {exc.code}: {exc.reason}"
        if provider in RESPONSES_PROVIDERS:
            result["api"]["http_status"] = exc.code
    except (urllib.error.URLError, TimeoutError, ConnectionError, http.client.HTTPException, RuntimeError) as exc:
        result["status"] = "model_error"
        result["exception"] = str(exc)
        result["http_timeout"] = isinstance(exc, TimeoutError) or isinstance(
            getattr(exc, "reason", None), TimeoutError)
    except (ValueError, TypeError, KeyError, AttributeError) as exc:
        result["status"] = "invalid_model_output"
        result["exception"] = str(exc)
    finally:
        result["elapsed_seconds"] = time.monotonic() - started
        if api_key and result["exception"]:
            result["exception"] = result["exception"].replace(api_key, "[REDACTED]")
    return result, predicates


def call_ollama(messages, *, model_name, ollama_url, options, timeout, think=None,
                keep_alive=None):
    """Return a response record and separately parsed predicates, or a failure."""
    payload = {"model": model_name, "messages": messages, "format": SCHEMA,
               "stream": False, "options": options}
    if think is not None:
        payload["think"] = think
    if keep_alive is not None:
        payload["keep_alive"] = keep_alive
    request = urllib.request.Request(ollama_url.rstrip("/") + "/api/chat",
        data=json.dumps(payload).encode(), headers={"Content-Type": "application/json"})
    return _request(request, timeout, "ollama")


def call_model(messages, config):
    provider = config.get("provider", "ollama")
    if provider == "ollama":
        return call_ollama(messages, model_name=config["model"], ollama_url=config["ollama_url"],
            options=config["model_options"], timeout=config["http_timeout"],
            think=config.get("think"), keep_alive=config.get("keep_alive"))
    if provider not in RESPONSES_PROVIDERS:
        raise ValueError(f"Unknown model provider: {provider}")
    settings = RESPONSES_PROVIDERS[provider]
    api_key = os.environ.get(settings["key_env"], "").strip()
    if not api_key:
        result = _response_record(provider)
        result.update(status="model_error", exception=f"{settings['key_env']} is not set")
        return result, None
    payload = {"model": config["model"], "input": messages,
        "reasoning": {"effort": config.get("reasoning_effort", settings["default_effort"])},
        "max_output_tokens": config["model_options"]["num_predict"],
        "text": {"format": {"type": "json_schema", "name": "sml_contract",
                            "schema": SCHEMA}}}
    if provider == "openai":
        payload["store"] = False
        payload["text"]["format"]["strict"] = True
    request = urllib.request.Request(settings["base_url"] + "/responses",
        data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json", "Authorization": f"Bearer {api_key}"})
    return _request(request, config["http_timeout"], provider, api_key)

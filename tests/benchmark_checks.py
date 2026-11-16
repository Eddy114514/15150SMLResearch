"""Offline tests of the benchmark grid, candidate scoring and result persistence."""
from contextlib import redirect_stdout
import io
import json
from pathlib import Path
import sys
import tempfile
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
import benchmark
import run
import sml


def request(status="ok", compiled=None):
    result = {"status": status, "raw_response": json.dumps({"offline": True, "status": status}),
              "exception": "MOCK_ONLY HTTP 402" if status == "model_error" else None,
              "elapsed_seconds": 0.01, "backend_metrics": {
                  "prompt_eval_count": 10, "eval_count": 4, "reasoning_tokens": 2}}
    if compiled is not None:
        result["compile"] = compiled
    return result


def metric_checks():
    faithful = {"case_id": "example", "model_label": "offline", "version": "original", "topic": "test",
                "expected_status": "ok", "status": "faithful",
                "semantic": {"status": "passed_semantic_checks"},
                "execution": {"status": "counterexample", "pbt": {"status": "counterexample"},
                              "preparation": {"attempts": [request(compiled={"status": "compiled"})]}}}
    measured = benchmark.attempt_metrics(faithful)
    assert measured["final_translation_faithful"] and measured["pbt_pass"] is False
    refused = {**faithful, "expected_status": "unsupported", "semantic": None,
               "status": "refusal_status_match", "execution": {
                   "status": "translation_unsupported", "pbt": None,
                   "preparation": {"attempts": [request("unsupported")]}}}
    measured = benchmark.attempt_metrics(refused)
    assert measured["final_translation_faithful"] is None and measured["refusal_status_match"]
    assert measured["reason_review_pending"] and measured["pbt_pass"] is None
    waiting = {key: value for key, value in faithful.items() if key not in ("execution", "semantic")}
    waiting["status"] = "not_run"
    summary = benchmark.summarize([faithful, refused, waiting], {
        "models": {"offline": {}}, "versions": ["original"], "case_ids": ["example"]})["models"]["offline"]
    assert summary["denominator"] == 3 and summary["executable_denominator"] == 2
    assert summary["refusal_denominator"] == 1 and not summary["complete"]
    assert summary["final_translation_faithful"] == {"count": 1, "rate": 0.5}
    assert summary["refusal_status_match"] == {"count": 1, "rate": 1.0}
    assert summary["pbt_pass"] == {"count": 0, "rate": 0.0}


def mocked_grid_checks(output, config, plan):
    label = "DeepSeek-1017"
    config = {**config, "output_dir": str(output.relative_to(ROOT))}
    selected = {**config, "benchmark": {**config["benchmark"], "models": {
        label: config["benchmark"]["models"][label]}}}
    counts = {"helpers": [], "candidates": 0, "semantic": 0, "contradiction": 0}

    def compilation(case, path):
        return {"status": "compiled", "contract_path": str(path / "offline_contract.sml"),
                "module_name": "Offline_" + case["id"]}

    def helper(node, path, config, **kwargs):
        ident = node["case"]["id"]
        assert ident == "hw_heads" and kwargs["property_source"] == "manual"
        path.mkdir()
        counts["helpers"].append(ident)
        return {"status": "passed_sampled_tests",
                "preparation": {"mode": "manual", "compile": compilation(node["case"], path)},
                "pbt": {"status": "passed_sampled_tests", "accepted": 1000}}

    # Only callable helpers need a manual contract. Other tasks use fixed labels directly.
    without_manuals = {**plan, "nodes": {key: dict(node) for key, node in plan["nodes"].items()}}
    for ident, node in without_manuals["nodes"].items():
        if ident != "hw_heads":
            node.pop("manual_text", None)
    with patch.object(benchmark, "PREPARED", output / "prepared"), \
         patch.object(run, "run_case", side_effect=helper), \
         patch.object(sml, "evaluate_semantics", side_effect=AssertionError("prepare must not score standards")):
        assert benchmark.prepare(selected, without_manuals) == 0
    prepared = benchmark.read(output / "prepared/plan.json")
    assert len(prepared["case_ids"]) == 31 and prepared["versions"] == list(benchmark.VERSIONS)
    assert counts["helpers"] == ["hw_heads"]
    assert list(benchmark.read(Path(prepared["helpers"]))) == ["hw_heads"]
    attempts = benchmark.attempt_records(prepared, plan)
    assert len(attempts) == 186
    assert [row["case_id"] for row in attempts[:31]] == prepared["case_ids"]
    assert [row["case_id"] for row in attempts[31:62]] == prepared["case_ids"]
    assert all(row["version"] == "original" and row["repetition"] == 1 for row in attempts[:31])
    assert all(row["version"] == "original" and row["repetition"] == 2 for row in attempts[31:62])
    assert len(list(Path(prepared["prompts"]).glob("*/*/messages.json"))) == 93
    for prompt in Path(prepared["prompts"]).glob("*/*/messages.json"):
        messages = benchmark.read(prompt)
        task = json.loads(messages[1]["content"])
        case = plan["nodes"][prompt.parent.name]["case"]
        assert task["target"]["observation"] == case["observation"]
        assert task["target"]["budgets"] == case["budgets"]
        assert not {"expected_status", "reason", "defect", "original_specification",
                    "topic", "blocked_reasons"}.intersection(task["target"])
    local = benchmark.attempt_records({**prepared, "models": {"local": {"name": "offline-local"}}}, plan)
    assert local[0]["generation_seed"] == prepared["generation_seeds"][0]
    assert local[31]["generation_seed"] == prepared["generation_seeds"][1]

    # Trial expectations and topics come from the same current plan as prompt wording.
    ident = prepared["case_ids"][0]
    changed = {**plan, "specifications": {**plan["specifications"], ident: {
        **plan["specifications"][ident], "original": {
            **plan["specifications"][ident]["original"], "expected_status": "unsupported"}}},
        "benchmark_metadata": {**plan["benchmark_metadata"], ident: {
            **plan["benchmark_metadata"][ident], "topic": "current-topic"}}}
    current = benchmark.attempt_records(prepared, changed)[0]
    assert current["expected_status"] == "unsupported" and current["topic"] == "current-topic"

    entries = {entry["text"]: entry for versions in plan["specifications"].values() for entry in versions.values()}
    mismatch_done = False
    phase = "success"

    def candidate(node, path, candidate_config, **kwargs):
        nonlocal mismatch_done
        counts["candidates"] += 1
        path.mkdir(parents=True)
        assert candidate_config["valid_target"] == 1
        if phase == "http_error":
            return {"status": "model_error", "pbt": None,
                    "preparation": {"mode": "model", "attempts": [request("model_error")]}}
        if phase == "interrupt":
            run.dump(path / "translation.json", {"mode": "model", "attempts": [request()]})
            raise KeyboardInterrupt("MOCK_ONLY interrupted compiler")
        status = entries[node["contract"]]["expected_status"]
        if status != "ok" and not mismatch_done:
            status, mismatch_done = "ok", True
        return {"status": "counterexample" if status == "ok" else "translation_" + status,
                "pbt": {"status": "counterexample"} if status == "ok" else None,
                "preparation": {"mode": "model", "attempts": [
                    request(status, compilation(node["case"], path) if status == "ok" else None)]}}

    def semantic(case, compiled, path, **kwargs):
        assert compiled["module_name"] == "Offline_" + case["id"]
        assert "candidate" not in kwargs
        entry = plan["specifications"][case["id"]][path.parts[-4]]
        assert entry["expected_status"] == "ok"
        assert kwargs["contradiction"] == (entry.get("defect") == "contradiction")
        counts["semantic"] += 1
        counts["contradiction"] += kwargs["contradiction"]
        return {"status": "passed_semantic_checks"}

    artifacts = {}
    with patch.object(benchmark, "PREPARED", output / "prepared"), \
         patch.object(run, "run_case", side_effect=candidate), \
         patch.object(sml, "evaluate_semantics", side_effect=semantic):
        for phase in ("success", "http_error", "interrupt"):
            prior = set(output.glob("benchmark-*"))
            try:
                # Current root configuration supplies PBT budgets, without preparation-time freezing.
                benchmark.run_benchmark({**config, "valid_target": 1}, without_manuals)
                assert phase == "success"
            except RuntimeError as exc:
                assert phase == "http_error" and "402" in str(exc)
            except KeyboardInterrupt:
                assert phase == "interrupt"
            created = set(output.glob("benchmark-*")) - prior
            assert len(created) == 1
            directory = created.pop()
            rows = benchmark.read(directory / "results.json")
            run_record = benchmark.read(directory / "run.json")
            scored = benchmark.read(directory / "summary.json")["models"][label]
            assert len(rows) == 186 and {row["model_label"] for row in rows} == {label}
            assert all(row["generation_seed"] is None for row in rows)
            if phase == "success":
                assert run_record["complete"] and run_record["model_calls"] == 186
                assert scored["executable_denominator"] == counts["semantic"] == 108
                assert counts["contradiction"] == 28
                assert scored["final_translation_faithful"]["count"] == 108
                assert scored["refusal_status_match"]["count"] == 77
                assert scored["pbt_pass"]["count"] == 0
                assert scored["metric_denominators"]["pbt_pass"] == 109
                assert scored["requests"]["backend"]["eval_count"] == 744
                assert scored["requests"]["backend"]["reasoning_tokens"] == 372
            else:
                assert not run_record["complete"] and run_record["model_calls"] == 1
                assert rows[0]["status"] == "infrastructure_error"
                assert all(row["status"] == "not_run" for row in rows[1:])
                assert scored["requests"]["count"] == 1
            artifacts[phase] = str(directory)
    return artifacts, counts


def real_candidate_check(output, config):
    _, _, plan = run.load_plan(case_id="hw_remove", property_source="model")
    node = plan["nodes"]["hw_remove"]
    directory = output / "real_sml"
    directory.mkdir()
    predicates = {"status": "ok", "requires_expr": "true", "ensures_expr": "false", "reason": ""}
    with patch.object(run.model, "call_model", return_value=(request(), predicates)) as model_call:
        execution = run.run_case(node, directory / "candidate", config,
                                 helpers=(), dependencies=(), property_source="model", role="Candidate")
    assert model_call.call_count == 1 and execution["pbt"]["status"] == "counterexample"
    compiled = run.compilation(execution["preparation"])
    checked = sml.evaluate_semantics(node["case"], compiled, directory / "labels",
                                    timeout=config["sml_timeout"], contradiction=True)
    assert checked["status"] == "passed_semantic_checks" and checked["ensures_checked"] == 5
    candidate_dir = directory / "bad_domain"
    candidate_dir.mkdir()
    candidate = sml.compile_contract(node["case"], "false", "false", candidate_dir,
                                    attempt=0, timeout=config["sml_timeout"], role="Candidate")
    measured = sml.evaluate_semantics(node["case"], candidate, directory / "bad_domain_labels",
                                    timeout=config["sml_timeout"], contradiction=True)
    assert measured["status"] == "semantic_counterexample"
    assert measured["requires_checked"] == 3 and measured["ensures_checked"] == 5
    exception_dir = directory / "exception"
    exception_dir.mkdir()
    throwing = sml.compile_contract(node["case"], '(raise Fail "predicate")', "false", exception_dir,
                                   attempt=0, timeout=config["sml_timeout"], role="Candidate")
    exception = sml.evaluate_semantics(node["case"], throwing, directory / "exception_labels",
                                      timeout=config["sml_timeout"], contradiction=True)
    assert exception["status"] == "predicate_error" and exception["ensures_checked"] == 5
    run.dump(directory / "summary.json", {"execution": execution, "contradiction": checked,
        "requires_does_not_filter_ensures": measured, "predicate_exception": exception})


def main():
    config, cases, plan = benchmark.load_plan()
    assert all("benchmark" not in case for case in cases)
    assert "sublist_sum" not in {case["id"] for case in cases}
    assert set(plan["benchmark_metadata"]) == {case["id"] for case in cases if case.get("group") == "hw"}
    output = Path(tempfile.mkdtemp(prefix="benchmark-checks-", dir=ROOT / "runs"))
    (output / "MOCK_ONLY.txt").write_text("No real model requests. Grid responses mocked; candidate scoring also tested with real SML.\n")
    log = io.StringIO()
    with patch("urllib.request.urlopen", side_effect=AssertionError("Offline tests must not access HTTP")), \
         patch.object(run.model, "call_model", side_effect=AssertionError("Use an explicit mock response")), \
         redirect_stdout(log):
        metric_checks()
        artifacts, counts = mocked_grid_checks(output, config, plan)
        real_candidate_check(output, config)
    (output / "mock_flow.log").write_text(log.getvalue())
    summary = {"status": "passed", "real_model_calls": 0, "real_http_requests": 0,
               "specification_cells": 93, "attempts_per_model": 186, "mock_sessions": artifacts,
               "counts": counts,
               "checks": ["separate_case_metadata", "helper_pbt_only_prepare", "version_and_repetition_order",
                           "hidden_expected_status",
                          "candidate_scoring_independent_of_pbt", "refusal_status_scoring",
                          "api_error_stop", "interrupt_checkpoint", "real_contradiction_labels"]}
    run.dump(output / "summary.json", summary)
    print(json.dumps({"summary": str(output / "summary.json"), **summary}, indent=2))


if __name__ == "__main__":
    main()

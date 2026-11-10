#!/usr/bin/env python3
"""Exercise all active cases with manual predicates and no model requests.

Artifacts, including candidate inputs and fixed-label outcomes, stay in runs/.
"""
import argparse
from collections import Counter
import json
from pathlib import Path
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
import model
import run
import sml


RESULT_FIELDS = (
    "status", "stage", "attempted", "accepted", "passed", "discarded", "errored",
    "target_calls", "counterexample_input", "counterexample_output", "exception",
)

# The submitted tracker postcondition omits linking its chain endpoint to the
# output member. Its literal value condition requires every valid mascot.
# The unchanged implementation returns only reachable members: detecting this
# mismatch is the expected PBT result, independently of reference fidelity.
EXPECTED_PBT = {"hw_tracker": "counterexample"}


def runtime_files(paths):
    return [paths] if isinstance(paths, str) else paths


def inspect_artifacts(case, directory, result, config):
    """Check actual assembled files, ordering, isolation and candidate count."""
    preparation = result["preparation"]
    assert preparation["mode"] == "manual" and not preparation.get("attempts")
    assert run.compilation(preparation)["status"] == "compiled"
    assert not (directory / "translation.json").exists()
    predicate = (directory / "predicate.cm").read_text()
    for name in ("Target.sml", "target_wrapper.sml", "data_adapter.sml", "driver.sml"):
        assert name not in predicate, (case["id"], name)
    runtime = (directory / "runtime.cm").read_text()
    assert runtime.index("Target.sml") < runtime.index("bindings.sml") < runtime.index("driver.sml")
    for paths, assembled in (
        (case.get("target_wrapper"), "target_wrapper.sml"),
        (case.get("data_adapter", {}).get("file"), "data_adapter.sml"),
    ):
        if paths is not None:
            expected = "\n".join((ROOT / path).read_text() for path in runtime_files(paths))
            allowed = [expected]
            if assembled == "data_adapter.sml":
                allowed.append(expected + f'\nstructure Data = {case["data_adapter"]["structure"]}\n')
            assert (directory / assembled).read_text() in allowed, (case["id"], assembled)
            assert assembled in runtime and assembled not in predicate
    inputs = (directory / "inputs.json").read_bytes()
    assert len(json.loads(inputs)) == config["max_attempts"]
    return {key: result["pbt"].get(key) for key in RESULT_FIELDS}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, help="new directory for complete artifacts")
    args = parser.parse_args()
    config, all_cases, plan = run.load_plan()
    cases = [plan["nodes"][ident]["case"] for ident in plan["roots"]]
    excluded = {case["id"] for case in all_cases if case.get("enabled", True) is False}
    by_id = {case["id"]: case for case in all_cases}
    assert all("manual_text" in node for node in plan["nodes"].values())
    semantic_cases = [case for case in cases if case.get("group") == "hw"]
    if args.output:
        output = args.output.resolve()
        output.mkdir(parents=True)
    else:
        (ROOT / "runs").mkdir(exist_ok=True)
        output = Path(tempfile.mkdtemp(prefix="pbt-regression-", dir=ROOT / "runs"))
    summary = {
        "settings": {key: config[key] for key in ("seed", "valid_target", "max_attempts")},
        "cases": {},
    }

    # Fail before a request could escape: observation only, no production monkeypatch.
    forbidden = {model.call_model.__code__, model.call_ollama.__code__, run.translate.__code__}
    manual_compiles, semantic_checks = Counter(), Counter()
    def no_model(frame, event, arg):
        if event == "call" and frame.f_code in forbidden:
            raise AssertionError("Regression checks must never request a model")
        if event == "call" and frame.f_code == sml.compile_manual_contract.__code__:
            manual_compiles[frame.f_locals["case"]["id"]] += 1
        if event == "call" and frame.f_code in (sml.compile_manual_contract.__code__, sml.compile_contract.__code__):
            ident = frame.f_locals["case"]["id"]
            assert ident not in excluded, f"Disabled case must not be compiled: {ident}"
        if event == "call" and frame.f_code == sml.evaluate_semantics.__code__:
            ident = frame.f_locals["case"]["id"]
            assert ident not in excluded, f"Disabled case must not be evaluated: {ident}"
            semantic_checks[ident] += 1
    sys.setprofile(no_model)
    try:
        _, _, model_plan = run.load_plan(property_source="model")
        assert model_plan["order"] == plan["order"]
        assert model_plan["errors"] == plan["errors"]
        for ident, node in model_plan["nodes"].items():
            assert node["property_source"] == "model"
            for key in ("contract", "dependencies", "helpers"):
                assert node[key] == plan["nodes"][ident][key], (ident, key)
        manual_dir = output / "manual"
        manual_dir.mkdir()
        results = run.run_plan(plan, manual_dir, config)
        for ident, result in results.items():
            assert result["status"] == EXPECTED_PBT.get(ident, "passed_sampled_tests"), (ident, result["status"])
            summary["cases"][ident] = inspect_artifacts(by_id[ident], manual_dir / ident, result, config)
            compiled = run.compilation(result["preparation"])
            node = plan["nodes"][ident]
            if node["case"].get("group") != "hw":
                continue
            semantic_dir = manual_dir / ident / "semantic"
            semantic = sml.evaluate_semantics(node["case"], compiled, semantic_dir,
                timeout=config["sml_timeout"],
                source=node["source_text"], helpers=run.provided_helpers(node, results),
                dependencies=run.runtime_dependencies(ident, plan, results))
            assert semantic["status"] == "passed_semantic_checks", (ident, semantic)
            assert semantic["requires_checked"] == semantic["requires_valid"] + semantic["requires_invalid"]
            assert semantic["ensures_checked"] == semantic["ensures_positive"] + semantic["ensures_negative"]
            run.dump(semantic_dir / "result.json", semantic)
        assert manual_compiles == Counter({case["id"]: 1 for case in cases}), manual_compiles
        assert semantic_checks == Counter({case["id"]: 1 for case in semantic_cases}), semantic_checks

        isolation = output / "predicate_isolation"
        isolation.mkdir()
        rejected = sml.compile_contract(by_id["is_even"], "true",
            "let val _ = Target.run val _ = TargetAdapter.run val _ = Data.genInput in true end",
            isolation, attempt=0, timeout=config["sml_timeout"])
        assert rejected["status"] == "compile_error"
        for structure in ("Target", "TargetAdapter", "Data"):
            assert f"unbound structure: {structure} in path" in rejected["diagnostics"]
        summary["predicate_isolation"] = "runtime names rejected"
    finally:
        sys.setprofile(None)

    run.dump(output / "summary.json", summary)
    counts = dict(Counter(item["status"] for item in summary["cases"].values()))
    print(json.dumps({"summary": str(output / "summary.json"), "cases": counts,
                      "manual_compiles": sum(manual_compiles.values()),
                      "standard_label_checks": sum(semantic_checks.values()),
                      "excluded_case_ids": sorted(excluded),
                      "model_calls": 0}, indent=2))


if __name__ == "__main__":
    main()

"""Run ordinary planning and a real SML/PBT CLI with benchmark reads forbidden."""
from contextlib import redirect_stdout
import io
import json
from pathlib import Path
import sys
import tempfile
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
import model
import run


# Replay the saved Luna expressions, not a new model or API response.
PREDICATES = {
    "status": "ok",
    "requires_expr": "true",
    "ensures_expr": (
        "case result of SOME ys => SublistModel.subsequence ys xs andalso "
        "SublistModel.sum ys = IntInf.fromInt n | NONE => "
        "not (Spec.member (IntInf.fromInt n) (SublistModel.selectionSums xs))"
    ),
    "reason": "",
}


def main():
    (ROOT / "runs").mkdir(exist_ok=True)
    output = Path(tempfile.mkdtemp(prefix="pipeline-boundary-", dir=ROOT / "runs"))
    (output / "MOCK_ONLY.txt").write_text(
        "No model requests or API charges. Saved predicate expressions replayed; "
        "CLI selection, SML compilation and PBT are real.\n")
    forbidden = [ROOT / "benchmark", ROOT / "tasks/hw/evaluation"]
    original_open, original_load_plan = Path.open, run.load_plan
    reads = []

    def pipeline_open(path, *args, **kwargs):
        resolved = path.resolve()
        assert not any(resolved.is_relative_to(folder) for folder in forbidden), resolved
        mode = args[0] if args else kwargs.get("mode", "r")
        if "r" in mode and resolved.is_relative_to(ROOT):
            reads.append(str(resolved.relative_to(ROOT)))
        return original_open(path, *args, **kwargs)

    def redirected_plan(**kwargs):
        config, cases, plan = original_load_plan(**kwargs)
        assert not {"benchmark", "generation_seeds"}.intersection(config)
        assert not {"specifications", "benchmark_metadata"}.intersection(plan)
        return {**config, "output_dir": str(output.relative_to(ROOT))}, cases, plan

    log = io.StringIO()
    with patch.object(Path, "open", pipeline_open), \
         patch("urllib.request.urlopen", side_effect=AssertionError("No HTTP allowed")):
        config, _, manual_plan = original_load_plan()
        _, _, model_plan = original_load_plan(property_source="model")
        assert len(manual_plan["order"]) == 42
        assert model_plan["order"] == manual_plan["order"]
        assert not manual_plan["errors"] and not model_plan["errors"]
        assert all(node["property_source"] == "manual" for node in manual_plan["nodes"].values())
        assert all(node["property_source"] == "model" for node in model_plan["nodes"].values())
        assert not {"benchmark", "generation_seeds"}.intersection(config)
        assert not {"specifications", "benchmark_metadata"}.intersection(model_plan)
        node = model_plan["nodes"]["hw_sublist_sum"]
        case = node["case"]
        expected_target = {key: case[key] for key in (
            "entrypoint", "input_type", "output_type", "input_pattern", "observation", "budgets")}
        expected_target["contract"] = node["contract"]

        def replay(messages, selected):
            assert selected["model"] == config["models"]["GPT-Luna"]["name"] == "gpt-6-luna"
            assert selected["provider"] == "openai"
            assert not {"benchmark", "generation_seeds"}.intersection(selected)
            task = json.loads(messages[1]["content"])
            assert set(task) == {"target", "helpers", "interface_context"}
            assert task["target"] == expected_target
            assert task["helpers"] == []
            assert task["interface_context"] == case["_context"]["interface_context"]
            return {"status": "ok", "raw_response": json.dumps(PREDICATES),
                    "mock_only": True}, dict(PREDICATES)

        with patch.object(run, "load_plan", side_effect=redirected_plan), \
             patch.object(model, "call_model", side_effect=replay) as model_call, \
             patch.object(sys, "argv", ["run.py", "--case", "hw_sublist_sum",
                                        "--properties", "model", "--model", "GPT-Luna"]), \
             redirect_stdout(log):
            assert run.main() == 0
        assert model_call.call_count == 1
        records = list(output.glob("*/run.json"))
        assert len(records) == 1
        record = json.loads(records[0].read_text())
        result = json.loads((records[0].parent / "hw_sublist_sum/result.json").read_text())
        assert record["complete"] and record["model_calls"] == 1
        assert record["plan"]["roots"] == record["plan"]["order"] == ["hw_sublist_sum"]
        assert result["preparation"]["mode"] == "model"
        assert run.compilation(result["preparation"])["status"] == "compiled"
        assert result["status"] == "passed_sampled_tests"
        assert result["pbt"]["accepted"] == result["pbt"]["passed"] == 1000

    (output / "cli.log").write_text(log.getvalue())
    summary = {"status": "passed", "planned_cases": len(model_plan["order"]),
               "case_id": "hw_sublist_sum", "pbt": result["pbt"]["status"],
               "accepted": result["pbt"]["accepted"], "real_model_calls": 0,
               "replayed_responses": 1, "forbidden_reads": [str(path.relative_to(ROOT)) for path in forbidden],
               "files_read": sorted(set(reads)), "run_directory": str(records[0].parent)}
    run.dump(output / "summary.json", summary)
    print(json.dumps({"summary": str(output / "summary.json"),
                      **{key: value for key, value in summary.items() if key != "files_read"}}, indent=2))


if __name__ == "__main__":
    main()

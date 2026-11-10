"""Check actual SML compilation failures and one repair, without model requests."""
import json
from pathlib import Path
import re
import sys
import tempfile
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
import model
import run
import sml


# Actual output from runs/benchmark-f8c2a02021/7B/hw_remove/3.
# SML/NJ reports both predicate source errors and a cascading predicate.cm error.
BAD = "forall i. 0 <= i < List.length xs' -> List.nth (xs', i) = (if List.nth (xs, i) = x then List.nth (xs', i+1) else List.nth (xs, i))"
GOOD = "result = List.filter (fn value => value <> x) xs"


def reply(ensures):
    predicates = {"status": "ok", "requires_expr": "true", "ensures_expr": ensures, "reason": ""}
    return {"status": "ok", "raw_response": json.dumps({
        "message": {"content": json.dumps(predicates)}})}, predicates


def check(output, config, node):
    case = node["case"]

    def compile_at(name, selected, ensures):
        directory = output / name
        directory.mkdir()
        return sml.compile_contract(selected, "true", ensures, directory,
                                    attempt=0, timeout=config["sml_timeout"], role="Candidate")

    valid = compile_at("valid", case, GOOD)
    assert valid["status"] == "compiled", valid
    invalid = compile_at("syntax_cascade", case, BAD)
    assert invalid["status"] == "compile_error", invalid
    assert re.search(r"initial_contract\.sml:\d+[^\n]*Error:", invalid["diagnostics"])
    assert re.search(r"predicate\.cm:\d+[^\n]*Error:", invalid["diagnostics"])
    for name, expression in (("type_error", "result"), ("empty_expression", "")):
        rejected = compile_at(name, case, expression)
        assert rejected["status"] == "compile_error", rejected

    manual_dir = output / "manual"
    manual_dir.mkdir()
    manual = sml.compile_manual_contract(case, node["manual_text"], manual_dir,
        timeout=config["sml_timeout"])
    assert manual["status"] == "compiled", manual

    header_case = {**case, "input_type": "MissingInput.t", "input_pattern": "input"}
    support = output / "support"
    support.mkdir()
    (support / "Broken.sml").write_text("structure Broken = struct val value : int = true end\n")
    (support / "support.cm").write_text("Group is\n  $/basis.cm\n  Broken.sml\n")
    support_case = {**case, "_context": {**case["_context"],
                    "support_libraries": [str(support / "support.cm")]}}
    for name, selected, ensures, evidence in (
        ("manifest_type_error", header_case, "true", "MissingInput"),
        ("support_error", support_case, "Broken.value = 0", "Broken.sml"),
    ):
        rejected = compile_at(name, selected, ensures)
        assert rejected["status"] == "compile_error", rejected
        assert evidence in rejected["diagnostics"], rejected["diagnostics"]

    for name, second, final_status in (
        ("repair_success", GOOD, "compiled"),
        ("repair_exhausted", BAD, "compile_error"),
    ):
        directory = output / name
        directory.mkdir()
        with patch.object(model, "call_ollama", side_effect=[reply(BAD), reply(second)]) as stub:
            preparation = run.translate(case, node["contract"], directory, config, role="Candidate")
        assert stub.call_count == 2
        assert [attempt["compile"]["status"] for attempt in preparation["attempts"]] == [
            "compile_error", final_status]
        repair_message = stub.call_args_list[1].args[0][-1]["content"]
        assert "predicate_compile_diagnostics" in repair_message and "predicate.cm:" in repair_message
        assert (directory / "initial_contract.sml").is_file()
        assert (directory / "repaired_contract.sml").is_file()


def main():
    config, _, plan = run.load_plan(case_id="hw_remove", property_source="model")
    (ROOT / "runs").mkdir(exist_ok=True)
    output = Path(tempfile.mkdtemp(prefix="compiler-checks-", dir=ROOT / "runs"))
    with patch("urllib.request.urlopen", side_effect=AssertionError("Compiler checks must stay offline")):
        check(output, config, plan["nodes"]["hw_remove"])
    summary = {"status": "passed", "checks": ["valid_compile", "syntax_with_cm_cascade",
        "predicate_type_error", "empty_predicate_compile_error", "manual_compile",
        "manifest_type_error", "support_library_error", "one_successful_repair", "repair_limit"],
        "model_calls": 0, "stub_calls": 4}
    run.dump(output / "summary.json", summary)
    print(json.dumps({"summary": str(output / "summary.json"), **summary}, indent=2))


if __name__ == "__main__":
    main()

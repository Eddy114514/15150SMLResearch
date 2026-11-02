#!/usr/bin/env python3
"""Exercise the active manifest without Ollama and compare deterministic results.

Run with Python and SML/NJ from any directory. Defaults come from config.json.
Use --baseline /path/to/summary.json to compare candidates and observable results
from a previous checkout. Artifacts, including all candidate inputs, stay in runs/.
The twelve model cases use fixed regression predicates, not model translations.
"""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
import corpus
import model
import run
import sml


FIXED = {
    "flatten": ("true", "result = List.concat LL"),
    "isprime": ("true", "result = (x >= 2 andalso Spec.forallRange (fn d => x mod d <> 0) (2, x div 2))"),
    "sublist_sum": ("true", """let
      fun subseq [] _ = true
        | subseq _ [] = false
        | subseq (ys as y::rest) (x::xs) =
            if y = x then subseq rest xs else subseq ys xs
      fun possible [] k = k = 0
        | possible (x::xs) k = possible xs k orelse possible xs (k - IntInf.fromInt x)
    in case result of
      NONE => not (possible L (IntInf.fromInt n))
    | SOME ys => subseq ys L andalso
        List.foldl (fn (x,s) => IntInf.fromInt x + s) 0 ys = IntInf.fromInt n
    end"""),
    "list_max": ("not (null xs)", "List.all (fn x => result >= x) xs andalso Spec.member result xs"),
    "is_even": ("true", "result = (x mod 2 = 0)"),
    "all_even": ("true", "result = List.all Helpers.isEven xs"),
    "tree_is_leaf": ("true", "result = (case tree of Tree.Leaf _ => true | Tree.Node _ => false)"),
    "seq_reverse_int": ("true", "Seq.toList result = List.rev (Seq.toList xs)"),
    "seq_reverse_bool": ("true", "Seq.toList result = List.rev (Seq.toList xs)"),
    "seq_flatten_int": ("true", "Seq.toList result = List.concat (List.map Seq.toList (Seq.toList xss))"),
    "seq_leaf_flags": ("true", "Seq.toList result = List.map (fn Tree.Leaf _ => true | Tree.Node _ => false) (Seq.toList trees)"),
    "list_to_seq": ("true", "Seq.toList result = xs"),
}
RESULT_FIELDS = (
    "status", "stage", "attempted", "accepted", "passed", "discarded", "errored",
    "target_calls", "counterexample_input", "counterexample_output", "exception",
)
KNOWN_COUNTEREXAMPLES = {"hw_book_flip", "hw_book_trace", "hw_lazy_interleave"}


def digest(data):
    return hashlib.sha256(data).hexdigest()


def runtime_files(paths):
    return [paths] if isinstance(paths, str) else paths


def inspect_artifacts(case, directory, result, config):
    """Check actual assembled files, ordering, isolation and candidate count."""
    assert result.get("model_calls", 0) == 0
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
    return {**{key: result.get(key) for key in RESULT_FIELDS}, "inputs_sha256": digest(inputs)}


def execute_fixed(case, source, predicates, directory, config, *, helpers=(), dependencies=()):
    directory.mkdir()
    compiled = sml.compile_contract(case, *predicates, directory, attempt=0,
                                    timeout=config["sml_timeout"], helpers=helpers)
    assert compiled["status"] == "compiled", case["id"]
    result = sml.execute(case, compiled["contract_path"], source, directory,
        seed=config["seed"], valid_target=config["valid_target"],
        max_attempts=config["max_attempts"], timeout=config["sml_timeout"],
        helpers=helpers, dependencies=dependencies)
    assert result["status"] == "passed_sampled_tests", (case["id"], result["status"])
    run.dump(directory / "result.json", {key: result.get(key) for key in RESULT_FIELDS})
    return {**result, "contract_path": compiled["contract_path"]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline", type=Path)
    parser.add_argument("--output", type=Path, help="new directory for complete artifacts")
    args = parser.parse_args()
    config = json.loads((ROOT / "config.json").read_text())
    manifest = ROOT / config["manifest"]
    cases = json.loads(manifest.read_text())["cases"]
    by_id = {case["id"]: case for case in cases}
    manual = [case for case in cases if "contract_file" in case]
    automatic = [case for case in cases if "contract_file" not in case]
    assert {case["id"] for case in automatic} == FIXED.keys(), "Update fixed predicates for changed manifest cases"
    if args.output:
        output = args.output.resolve()
        output.mkdir(parents=True)
    else:
        (ROOT / "runs").mkdir(exist_ok=True)
        output = Path(tempfile.mkdtemp(prefix="pbt-regression-", dir=ROOT / "runs"))
    summary = {
        "settings": {key: config[key] for key in ("seed", "valid_target", "max_attempts")},
        "cases": {}, "sorted_builtins": {}, "solutions": {},
    }

    # Fail before a request could escape: observation only, no production monkeypatch.
    forbidden = {model.call_ollama.__code__, run.translate.__code__}
    def no_model(frame, event, arg):
        if event == "call" and frame.f_code in forbidden:
            raise AssertionError("Regression checks must never request a model")
    sys.setprofile(no_model)
    try:
        manual_dir = output / "manual"
        manual_dir.mkdir()
        plan = corpus.plan(cases, manual, manifest.parent)
        results = run.run_plan(plan, manual_dir, config, {})
        for ident, result in results.items():
            expected = "counterexample" if ident in KNOWN_COUNTEREXAMPLES else "passed_sampled_tests"
            assert result["status"] == expected, (ident, result["status"])
            assert result["final_compile_ok"] is True
            summary["cases"][ident] = inspect_artifacts(by_id[ident], manual_dir / ident, result, config)

        fixtures = output / "fixed"
        fixtures.mkdir()
        fixed_plan = corpus.plan(cases, automatic, manifest.parent)
        fixed_results = {}
        for ident in fixed_plan["order"]:
            node = fixed_plan["nodes"][ident]
            assert not fixed_plan["errors"].get(ident)
            result = execute_fixed(node["case"], node["source_text"], FIXED[ident],
                fixtures / ident, config, helpers=run.provided_helpers(node, fixed_results),
                dependencies=run.runtime_dependencies(ident, fixed_plan, fixed_results))
            fixed_results[ident] = result
            summary["cases"][ident] = inspect_artifacts(node["case"], fixtures / ident, result, config)

        # All sortable builtins, including the pair route absent from model cases.
        for generator, input_type, expression in (
            ("int_list", "int list", "List.length input"),
            ("int_list_pair", "int * int list", "#1 input"),
            ("list_int_pair", "int list * int", "#2 input"),
        ):
            case = {"id": "sorted_" + generator, "entrypoint": "echo",
                    "input_type": input_type, "output_type": "int", "input_pattern": "input",
                    "generator": generator, "generator_options": {"sort_lists": True}}
            directory = fixtures / case["id"]
            result = execute_fixed(case,
                f"fun echo (input : {input_type}) = {expression}\n",
                ("true", f"result = ({expression})"), directory, config)
            summary["sorted_builtins"][generator] = inspect_artifacts(case, directory, result, config)
            samples = json.loads((directory / "inputs.json").read_text())
            lists = samples if generator == "int_list" else [
                sample[1] if generator == "int_list_pair" else sample[0] for sample in samples]
            assert lists[6 if generator == "int_list" else 7] == [3, 2, 1]
            assert all(xs == sorted(xs) for xs in lists[11:]), generator

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

    for case in cases:
        text = (manifest.parent / case["source"]).read_text()
        solution, _ = corpus.split_task_file(text)
        summary["solutions"][case["source"]] = digest(solution.encode())
    run.dump(output / "summary.json", summary)
    if args.baseline:
        baseline = json.loads(args.baseline.read_text())
        differences = []
        for section, actual in summary.items():
            old = baseline.get(section)
            if isinstance(actual, dict) and isinstance(old, dict):
                differences += [f"{section}.{key}" for key in actual.keys() | old.keys()
                                if actual.get(key) != old.get(key)]
            elif actual != old:
                differences.append(section)
        assert not differences, f"Baseline differences: {', '.join(differences)}; inspect {output}"
    counts = dict(Counter(item["status"] for item in summary["cases"].values()))
    print(json.dumps({"summary": str(output / "summary.json"), "cases": counts,
                      "model_calls": 0, "baseline_equal": bool(args.baseline)}, indent=2))


if __name__ == "__main__":
    main()

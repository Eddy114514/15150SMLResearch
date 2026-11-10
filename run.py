#!/usr/bin/env python3
"""Compile manual or translated SML contracts and test their implementations."""
import argparse
import csv
import datetime as dt
import json
from pathlib import Path
import sys
import time
import uuid

import corpus
import model
import sml

ROOT = Path(__file__).resolve().parent


def persisted(value):
    if isinstance(value, dict):
        return {key: persisted(item) for key, item in value.items() if key != "diagnostics"}
    if isinstance(value, list):
        return [persisted(item) for item in value]
    return value


def dump(path, value):
    path.write_text(json.dumps(persisted(value), ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def csv_row(record):
    return {key: json.dumps(value, ensure_ascii=False) if isinstance(value, (dict, list)) else value
            for key, value in record.items()}


def write_csv(path, records):
    if not records:
        return
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(dict.fromkeys(key for row in records for key in row)))
        writer.writeheader()
        writer.writerows(csv_row(record) for record in records)


def now():
    return dt.datetime.now(dt.timezone.utc).isoformat()


def load_plan(*, case_id=None, file_path=None, group=None, property_source="auto"):
    config = json.loads((ROOT / "config.json").read_text(encoding="utf-8"))
    manifest = (ROOT / config["manifest"]).resolve()
    cases = json.loads(manifest.read_text(encoding="utf-8"))["cases"]
    roots = [case for case in cases if case.get("enabled", True)
             and (group is None or case.get("group") == group)]
    if case_id is not None:
        roots = [case for case in roots if case["id"] == case_id]
    elif file_path is not None:
        source = (ROOT / file_path).resolve()
        roots = [case for case in roots if (manifest.parent / case["source"]).resolve() == source]
    return config, cases, corpus.plan(cases, roots, manifest.parent, property_source=property_source)


def prompt_messages(case, contract, helpers=()):
    """Preview and generation use the same planned capability context."""
    task_data = model.build_task_data(case, contract, helpers)
    task_data["interface_context"] = case["_context"]["interface_context"]
    return model.initial_messages(task_data, (ROOT / "prompts/translate.txt").read_text(encoding="utf-8"))


def translate(case, contract, workdir, config, helpers=(), *, role=""):
    messages = prompt_messages(case, contract, helpers)
    dump(workdir / "messages.json", messages)
    preparation = {"mode": "model", "attempts": []}
    for attempt in range(2):
        response, predicates = model.call_model(messages, config)
        preparation["attempts"].append(response)
        # Checkpoint the raw response before compilation, including local failures.
        dump(workdir / "translation.json", preparation)
        if response["status"] != "ok":
            break
        compiled = sml.compile_contract(case, predicates["requires_expr"], predicates["ensures_expr"],
            workdir, attempt=attempt, timeout=config["sml_timeout"], helpers=helpers, role=role)
        response["compile"] = compiled
        dump(workdir / "translation.json", preparation)
        if attempt or compiled["status"] != "compile_error":
            break
        content = json.dumps(predicates, ensure_ascii=False)
        messages = model.repair_messages(messages, content, compiled["diagnostics"], (ROOT / "prompts/repair.txt").read_text(encoding="utf-8"))
    return preparation


def prepare_manual(node, workdir, config, helpers, *, role=""):
    return {"mode": "manual", "compile": sml.compile_manual_contract(
        node["case"], node["manual_text"], workdir, timeout=config["sml_timeout"], helpers=helpers, role=role)}


def compilation(preparation):
    if not preparation:
        return {}
    return preparation.get("compile") or next(
        (item["compile"] for item in reversed(preparation.get("attempts", [])) if "compile" in item), {})


def run_case(node, workdir, config, *, helpers, dependencies, property_source=None, role="",
             test_implementation=True):
    started = time.monotonic()
    case = node["case"]
    workdir.mkdir()
    mode = property_source or node["property_source"]
    if mode == "manual":
        preparation = prepare_manual(node, workdir, config, helpers, role=role)
        terminal = preparation["compile"]
    elif mode == "model":
        preparation = translate(case, node["contract"], workdir, config, helpers, role=role)
        last = preparation["attempts"][-1]
        terminal = last.get("compile", last)
    else:
        raise ValueError(f"Unknown property source: {mode}")
    measured = None
    if terminal["status"] == "compiled" and test_implementation:
        compiled = compilation(preparation)
        measured = sml.execute(case, compiled["contract_path"], node["source_text"], workdir,
            seed=config["seed"], valid_target=config["valid_target"], max_attempts=config["max_attempts"],
            timeout=config["sml_timeout"], helpers=helpers, dependencies=dependencies, role=role)
    terminal = measured or terminal
    status = terminal["status"]
    return {"case_id": case["id"],
            "status": "translation_" + status if status in ("ambiguous", "unsupported") else status,
            "stage": terminal.get("stage", "model"), "preparation": preparation, "pbt": measured,
            "seconds": time.monotonic() - started}


def admitted(result):
    """Runner emits this status only after a complete failure-free PBT run."""
    return result.get("status") == "passed_sampled_tests"


def provided_helpers(node, results):
    return [{**helper, "status": results[helper["case_id"]]["status"]}
            for helper in node["helpers"]]


def blocked_dependencies(node, results):
    return [{"case_id": dep, "status": results.get(dep, {}).get("status", "not_run")}
            for dep in node["dependencies"]
            if not admitted(results.get(dep, {}))]


def runtime_dependencies(case_id, plan, results):
    return [{"case": plan["nodes"][ident]["case"],
             "contract_path": compilation(results[ident]["preparation"])["contract_path"],
             "module_name": compilation(results[ident]["preparation"])["module_name"],
             "helpers": provided_helpers(plan["nodes"][ident], results)}
            for ident in plan["nodes"][case_id]["dependency_order"]]


def run_plan(plan, run_dir, config):
    results = {}
    for ident in plan["order"]:
        node, workdir = plan["nodes"][ident], run_dir / ident
        errors = plan["errors"].get(ident, [])
        blocked = blocked_dependencies(node, results)
        if errors or blocked:
            workdir.mkdir()
            result = {"case_id": ident, "status": "blocked_dependency", "stage": "dependency",
                      "blocked_by": blocked, "dependency_errors": errors,
                      "preparation": None, "pbt": None, "seconds": 0.0}
            sml.log(workdir, "dependency", json.dumps({"errors": errors, "blocked_by": blocked}))
        else:
            result = run_case(node, workdir, config, helpers=provided_helpers(node, results),
                              dependencies=runtime_dependencies(ident, plan, results))
        dump(workdir / "result.json", result)
        results[ident] = result
        print(f"{ident}: {result['status']} ({result['stage']})", flush=True)
    return results


def main():
    started = time.monotonic()
    parser = argparse.ArgumentParser(description=__doc__)
    selection = parser.add_mutually_exclusive_group()
    selection.add_argument("--case", help="run a manifest case after its contract dependencies")
    selection.add_argument("--file", type=Path,
                           help="run a configured source's cases and dependencies, once each")
    selection.add_argument("--group", help="run the cases with this manifest group")
    parser.add_argument("--properties", choices=("auto", "manual", "model"), default="auto",
                        help="property source; auto uses an available manual standard, otherwise the model")
    parser.add_argument("--model", help="model label from config.benchmark.models")
    args = parser.parse_args()
    config, _, plan = load_plan(case_id=args.case, file_path=args.file, group=args.group,
                                property_source=args.properties)
    if args.model is not None:
        models = config["benchmark"]["models"]
        if args.model not in models:
            parser.error(f"unknown model label: {args.model}; choose from {', '.join(models)}")
        config = model.configure(config, models[args.model])
    if not plan["roots"]:
        parser.error(f"no enabled manifest cases match: {args.case or args.file or args.group}")
    stamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    run_dir = (ROOT / config["output_dir"]).resolve() / (stamp + "-" + uuid.uuid4().hex[:6])
    run_dir.mkdir(parents=True)
    record = {"started_at": now(), "config": config, "properties": args.properties,
              "plan": {key: plan[key] for key in ("roots", "order", "errors")},
              "dependencies": {ident: plan["nodes"][ident]["dependencies"] for ident in plan["order"]},
              "complete": False}
    dump(run_dir / "run.json", record)
    print("Run directory:", run_dir, flush=True)
    try:
        results = run_plan(plan, run_dir, config)
        record.update(complete=True, model_calls=sum(
            len((result.get("preparation") or {}).get("attempts", [])) for result in results.values()))
    finally:
        record["seconds"] = time.monotonic() - started
        dump(run_dir / "run.json", record)
    return 0


if __name__ == "__main__":
    sys.exit(main())

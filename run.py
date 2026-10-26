#!/usr/bin/env python3
"""Compile manual or translated SML contracts and test their implementations."""
import argparse
import csv
import datetime as dt
import hashlib
import json
from pathlib import Path
import sys
import time
import uuid

import corpus
import interfaces
import model
import sml

ROOT = Path(__file__).resolve().parent


def dump(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def now():
    return dt.datetime.now(dt.timezone.utc).isoformat()


def helper_metadata(helpers):
    return [{key: helper[key] for key in
             ("case_id", "callable_name", "signature", "status")} for helper in helpers]


def select_cases(cases, manifest, case_id, file_path, group=None):
    if case_id is not None:
        return [case for case in cases if case["id"] == case_id]
    if file_path is not None:
        source = (ROOT / file_path).resolve()
        return [case for case in cases if (manifest.parent / case["source"]).resolve() == source]
    if group is not None:
        return [case for case in cases if case.get("group") == group]
    return cases


def load_translation_resources(config):
    return {
        "catalog": interfaces.load(ROOT, config),
        "translate_prompt": (ROOT / "prompts/translate.txt").read_text(encoding="utf-8"),
        "repair_prompt": (ROOT / "prompts/repair.txt").read_text(encoding="utf-8"),
    }


def translate(case, contract, workdir, config, resources, helpers=()):
    task_data = model.build_task_data(case, contract, helpers)
    task_data["interface_context"] = interfaces.select(case, resources["catalog"])
    messages = model.initial_messages(task_data, resources["translate_prompt"])
    translation = {"attempts": [], "initial_compile_ok": None, "repair_attempted": False,
                   "source": case.get("source"), "contract_id": case.get("contract_id"),
                   "entrypoint": case["entrypoint"],
                   "provided_helpers": helper_metadata(helpers),
                   "interface_ids": [c["id"] for c in task_data["interface_context"]],
                   "interface_characters": sum(len(c["text"]) for c in task_data["interface_context"]),
                   "final_compile_ok": None, "repair_count": 0,
                   "model_seconds": 0.0, "status": None, "stage": "model",
                   "exception": None, "reason": None}
    for attempt in range(2):
        requested_at = now()
        response = model.call_ollama(messages, model_name=config["model"],
            ollama_url=config["ollama_url"], options=config["model_options"],
            timeout=config["http_timeout"], think=config.get("think"),
            keep_alive=config.get("keep_alive"))
        item = {"kind": "initial" if attempt == 0 else "repair",
                "requested_at": requested_at, "completed_at": now(), **response}
        translation["attempts"].append(item)
        translation["model_seconds"] += response["elapsed_seconds"]
        translation["repair_attempted"] = bool(attempt)
        translation["repair_count"] = attempt
        translation["final_compile_ok"] = None
        status = response["status"]
        predicates = response["predicates"]
        translation.update(
            status="translation_" + status if status in ("ambiguous", "unsupported") else status,
            stage="model", exception=response["exception"],
            reason=predicates.get("reason") if status in ("ambiguous", "unsupported") else None)
        # Preserve the real response even if a later local build error stops the command.
        dump(workdir / "translation.json", translation)
        if status != "ok":
            break
        compiled = sml.compile_contract(case, predicates["requires_expr"], predicates["ensures_expr"],
            workdir, attempt=attempt, timeout=config["sml_timeout"], helpers=helpers)
        item["compile"] = compiled
        translation["final_compile_ok"] = compiled.get("compile_ok")
        if attempt == 0 and compiled["status"] != "timeout":
            translation["initial_compile_ok"] = compiled["compile_ok"]
        translation.update(status=compiled["status"], stage=compiled["stage"],
                           exception=compiled.get("exception"))
        dump(workdir / "translation.json", translation)
        if compiled["status"] == "compiled":
            return compiled, translation
        if attempt or compiled["status"] != "compile_error":
            break
        messages = model.repair_messages(messages, response["raw_content"],
            compiled["diagnostics"], resources["repair_prompt"])
    return None, translation


def prepare_manual(node, workdir, config, helpers):
    """Use the manual snapshot directly; errors never fall back to translation."""
    case = node["case"]
    compiled = sml.compile_manual_contract(case, node["manual_text"], workdir,
        timeout=config["sml_timeout"], helpers=helpers)
    preparation = {
        "case_id": case["id"], "manual_section": node.get("manual_section"),
        "contract_file": case["contract_file"], "contract_id": case["contract_id"],
        "sha256": hashlib.sha256(node["manual_text"].encode("utf-8")).hexdigest(),
        "attempts": [], "model_calls": 0, "model_seconds": 0.0,
        "initial_compile_ok": compiled.get("compile_ok"),
        "final_compile_ok": compiled.get("compile_ok"),
        "repair_attempted": False, "repair_count": 0,
        "provided_helpers": helper_metadata(helpers),
        "interface_ids": [], "interface_characters": 0,
        "status": compiled["status"], "stage": compiled["stage"],
        "exception": compiled.get("exception"), "reason": None, "compile": compiled}
    dump(workdir / "manual_contract.json", preparation)
    return (compiled if compiled["status"] == "compiled" else None), preparation


def result_record(case, *, requested_root, direct_dependencies):
    """One result shape for executed cases and cases blocked before translation."""
    return {
        "case_id": case["id"], "source": case["source"],
        "contract_id": case["contract_id"], "entrypoint": case["entrypoint"],
        "contract_mode": "manual" if "contract_file" in case else "model",
        "contract_file": case.get("contract_file"), "target_wrapper": case.get("target_wrapper"),
        "requested_root": requested_root, "direct_dependencies": direct_dependencies,
        "blocked_by": [], "dependency_errors": [], "provided_helpers": [],
        "status": None, "stage": None,
        "initial_compile_ok": None, "final_compile_ok": None,
        "repair_attempted": False, "repair_count": 0, "model_calls": 0,
        **{key: None for key in ("attempted", "accepted", "discarded", "passed", "errored",
            "target_calls", "counterexample_input", "counterexample_output", "exception", "reason")},
        "model_seconds": 0.0, "interface_ids": [], "interface_characters": 0,
        "pbt_seconds": None, "case_seconds": 0.0,
        "started_at": None, "finished_at": None,
        "contract_path": None, "predicate_cm": None, "module_name": None,
        "main_path": None, "log": None,
    }


def run_case(node, workdir, config, resources, *, requested_root, helpers, dependencies):
    """Compile and test using source snapshots and this run's admitted helpers."""
    started = time.monotonic()
    started_at = now()
    case = node["case"]
    workdir.mkdir()
    if "contract_file" in case:
        compiled, preparation = prepare_manual(node, workdir, config, helpers)
    else:
        compiled, preparation = translate(case, node["contract"], workdir, config, resources, helpers)
    measured = {}
    if compiled is not None:
        measured = sml.execute(case, compiled["contract_path"], node["source_text"], workdir,
            seed=config["seed"], valid_target=config["valid_target"], max_attempts=config["max_attempts"],
            timeout=config["sml_timeout"], helpers=helpers, dependencies=dependencies)
    result = result_record(case, requested_root=requested_root,
                           direct_dependencies=node["dependencies"])
    artifacts = compiled or preparation.get("compile", {})
    result.update({
        "provided_helpers": preparation["provided_helpers"],
        "status": measured["status"] if measured else preparation["status"],
        "stage": measured["stage"] if measured else preparation["stage"],
        "initial_compile_ok": preparation["initial_compile_ok"],
        "final_compile_ok": preparation["final_compile_ok"],
        "repair_attempted": preparation["repair_attempted"],
        "repair_count": preparation["repair_count"],
        "model_calls": len(preparation["attempts"]),
        **{key: measured.get(key) for key in (
            "attempted", "accepted", "discarded", "passed", "errored", "target_calls",
            "counterexample_input", "counterexample_output")},
        "exception": measured.get("exception") if measured else preparation["exception"],
        "reason": preparation["reason"],
        "model_seconds": preparation["model_seconds"],
        "interface_ids": preparation["interface_ids"],
        "interface_characters": preparation["interface_characters"],
        "pbt_seconds": measured.get("elapsed_seconds"),
        "case_seconds": time.monotonic() - started,
        "started_at": started_at, "finished_at": now(),
        **{key: artifacts.get(key)
           for key in ("contract_path", "predicate_cm", "module_name")},
        "main_path": measured.get("main_path"),
        "log": str(workdir / "log.txt"),
    })
    sml.log(workdir, result["stage"], result["exception"] or result["reason"] or result["status"])
    dump(workdir / "result.json", result)
    return result


def admitted(result, config):
    """Only this run's successful independent check can supply a helper."""
    target = config["valid_target"]
    return (type(target) is int and target > 0
            and result.get("status") == "passed_sampled_tests"
            and result.get("final_compile_ok") is True
            and (result.get("accepted") or 0) >= target
            and (result.get("passed") or 0) >= (result.get("accepted") or 0)
            and result.get("errored") == 0
            and result.get("exception") is None
            and result.get("counterexample_input") is None
            and result.get("counterexample_output") is None)


def provided_helpers(node, results):
    return [{**helper, "status": results[helper["case_id"]]["status"]}
            for helper in node["helpers"]]


def runtime_dependencies(case_id, plan, results):
    needed = set()

    def visit(ident):
        for dependency in plan["nodes"][ident]["dependencies"]:
            if dependency not in needed:
                needed.add(dependency)
                visit(dependency)

    visit(case_id)
    return [{"case": plan["nodes"][ident]["case"],
             "contract_path": results[ident]["contract_path"],
             "helpers": provided_helpers(plan["nodes"][ident], results)}
            for ident in plan["order"] if ident in needed]


def run_plan(plan, run_dir, config, resources):
    """Execute each case once in dependency order, retaining original failures."""
    results = {}
    with (run_dir / "results.csv").open("w", newline="", encoding="utf-8") as handle:
        writer = None
        for ident in plan["order"]:
            node = plan["nodes"][ident]
            case, workdir = node["case"], run_dir / ident
            errors = plan["errors"].get(ident, [])
            blocked = [{"case_id": dep, "status": results.get(dep, {}).get("status", "not_run")}
                       for dep in node["dependencies"]
                       if not admitted(results.get(dep, {}), config)]
            if errors or blocked:
                workdir.mkdir()
                result = result_record(case, requested_root=ident in plan["roots"],
                                       direct_dependencies=node["dependencies"])
                result.update(status="blocked_dependency", stage="dependency",
                              blocked_by=blocked, dependency_errors=errors,
                              reason="Required contract dependencies are unavailable in this run.",
                              started_at=now(), finished_at=now(), log=str(workdir / "log.txt"))
                sml.log(workdir, "dependency", json.dumps({"errors": errors, "blocked_by": blocked}))
                dump(workdir / "result.json", result)
            else:
                result = run_case(node, workdir, config, resources,
                    requested_root=ident in plan["roots"], helpers=provided_helpers(node, results),
                    dependencies=runtime_dependencies(ident, plan, results))
            results[ident] = result
            if writer is None:
                writer = csv.DictWriter(handle, fieldnames=list(result))
                writer.writeheader()
            writer.writerow({key: json.dumps(value) if isinstance(value, (dict, list)) else value
                             for key, value in result.items()})
            handle.flush()
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
    args = parser.parse_args()
    config = json.loads((ROOT / "config.json").read_text(encoding="utf-8"))
    manifest = (ROOT / config["manifest"]).resolve()
    all_cases = json.loads(manifest.read_text(encoding="utf-8"))["cases"]
    cases = select_cases(all_cases, manifest, args.case, args.file, args.group)
    if not cases and (args.case is not None or args.file is not None or args.group is not None):
        parser.error(f"no manifest cases match: {args.case or args.file or args.group}")
    plan = corpus.plan(all_cases, cases, manifest.parent)
    resources = load_translation_resources(config) if any(
        "contract_file" not in node["case"] for node in plan["nodes"].values()) else {}
    stamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    run_dir = (ROOT / config["output_dir"]).resolve() / (stamp + "-" + uuid.uuid4().hex[:6])
    run_dir.mkdir(parents=True)
    snapshots, contract_snapshots = {}, {}
    for ident in plan["order"]:
        node = plan["nodes"][ident]
        source_path = str((manifest.parent / node["case"]["source"]).resolve())
        if source_path not in snapshots:
            snapshot_text = node.get("source_snapshot_text", node["source_text"])
            path = run_dir / "sources" / f"source_{len(snapshots)}.sml"
            path.parent.mkdir(exist_ok=True)
            path.write_text(snapshot_text, encoding="utf-8")
            snapshots[source_path] = {"snapshot": str(path),
                "sha256": hashlib.sha256(snapshot_text.encode("utf-8")).hexdigest()}
        if "manual_path" in node and node["manual_path"] not in contract_snapshots:
            snapshot_text = node.get("manual_snapshot_text", node["manual_text"])
            path = run_dir / "contracts" / f"contract_{len(contract_snapshots)}.sml"
            path.parent.mkdir(exist_ok=True)
            path.write_text(snapshot_text, encoding="utf-8")
            contract_snapshots[node["manual_path"]] = {"snapshot": str(path),
                "sha256": hashlib.sha256(snapshot_text.encode("utf-8")).hexdigest()}
    dump(run_dir / "run_config.json", {**config, "case_ids": plan["order"],
        "root_case_ids": plan["roots"], "source_snapshots": snapshots,
        "requested_group": args.group, "contract_snapshots": contract_snapshots,
        "direct_dependencies": {ident: plan["nodes"][ident]["dependencies"] for ident in plan["order"]},
        "dependency_errors": plan["errors"], "generator_implementation": "qcheck-gen-v1"})
    print("Run directory:", run_dir, flush=True)
    results = run_plan(plan, run_dir, config, resources)
    dump(run_dir / "batch_summary.json", {
        "case_count": len(results), "root_case_ids": plan["roots"],
        "case_order": plan["order"],
        "executed_case_ids": [ident for ident, result in results.items()
                              if result["status"] != "blocked_dependency"],
        "dependency_case_ids": [ident for ident in plan["order"] if ident not in plan["roots"]],
        "results": {ident: {key: result[key] for key in
                    ("status", "direct_dependencies", "blocked_by", "dependency_errors", "provided_helpers")}
                    for ident, result in results.items()},
        "model_calls": sum(result["model_calls"] for result in results.values()),
        "batch_seconds": time.monotonic() - started})
    return 0


if __name__ == "__main__":
    sys.exit(main())

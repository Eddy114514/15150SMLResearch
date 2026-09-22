#!/usr/bin/env python3
"""Translate configured SML contracts and test their student implementations."""
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


def dump(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def select_cases(cases, manifest, case_id, file_path):
    if case_id is not None:
        return [case for case in cases if case["id"] == case_id]
    if file_path is not None:
        source = (ROOT / file_path).resolve()
        return [case for case in cases if (manifest.parent / case["source"]).resolve() == source]
    return cases


def translate(case, contract, workdir, config, resources):
    task_data = model.build_task_data(case, contract)
    messages = model.initial_messages(task_data, resources["translate_prompt"])
    translation = {"attempts": [], "initial_compile_ok": None, "repair_attempted": False,
                   "final_compile_ok": None, "repair_count": 0,
                   "model_seconds": 0.0, "status": None, "stage": "model",
                   "exception": None, "reason": None}
    for attempt in range(2):
        response = model.call_ollama(messages, model_name=config["model"],
            ollama_url=config["ollama_url"], options=config["model_options"],
            timeout=config["http_timeout"], think=config.get("think"),
            keep_alive=config.get("keep_alive"))
        item = {"kind": "initial" if attempt == 0 else "repair", **response}
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
            workdir, attempt=attempt, timeout=config["sml_timeout"])
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
        messages = model.repair_messages(messages, task_data, response["raw_content"],
            compiled["diagnostics"], resources["repair_prompt"])
    return None, translation


def run_case(case, tasks_dir, workdir, config, resources):
    started = time.monotonic()
    workdir.mkdir()
    source = (tasks_dir / case["source"]).read_text(encoding="utf-8")
    contract = corpus.extract_contract(source, case["contract_id"])
    compiled, translation = translate(case, contract, workdir, config, resources)
    measured = {}
    if compiled is not None:
        measured = sml.execute(case, compiled["contract_path"], source, workdir,
            seed=config["seed"], valid_target=config["valid_target"], max_attempts=config["max_attempts"],
            timeout=config["sml_timeout"])
    result = {
        "case_id": case["id"],
        "status": measured["status"] if measured else translation["status"],
        "stage": measured["stage"] if measured else translation["stage"],
        "initial_compile_ok": translation["initial_compile_ok"],
        "final_compile_ok": translation["final_compile_ok"],
        "repair_attempted": translation["repair_attempted"],
        "repair_count": translation["repair_count"],
        **{key: measured.get(key) for key in (
            "attempted", "accepted", "discarded", "passed", "errored", "target_calls",
            "counterexample_input", "counterexample_output")},
        "exception": measured.get("exception") if measured else translation["exception"],
        "reason": translation["reason"],
        "model_seconds": translation["model_seconds"],
        "pbt_seconds": measured.get("elapsed_seconds"),
        "case_seconds": time.monotonic() - started,
        "main_path": measured.get("main_path"),
        "log": str(workdir / "log.txt"),
    }
    sml.log(workdir, result["stage"], result["exception"] or result["reason"] or result["status"])
    dump(workdir / "result.json", result)
    return result


def main():
    started = time.monotonic()
    parser = argparse.ArgumentParser(description=__doc__)
    selection = parser.add_mutually_exclusive_group()
    selection.add_argument("--case", help="run one manifest case")
    selection.add_argument("--file", type=Path, help="run all cases for a configured SML source")
    args = parser.parse_args()
    config = json.loads((ROOT / "config.json").read_text(encoding="utf-8"))
    manifest = (ROOT / config["manifest"]).resolve()
    cases = select_cases(json.loads(manifest.read_text(encoding="utf-8"))["cases"],
                         manifest, args.case, args.file)
    if not cases and (args.case is not None or args.file is not None):
        parser.error(f"no manifest cases match: {args.case or args.file}")
    resources = {
        "translate_prompt": (ROOT / "prompts/translate.txt").read_text(encoding="utf-8"),
        "repair_prompt": (ROOT / "prompts/repair.txt").read_text(encoding="utf-8"),
    }
    stamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    run_dir = (ROOT / config["output_dir"]).resolve() / (stamp + "-" + uuid.uuid4().hex[:6])
    run_dir.mkdir(parents=True)
    dump(run_dir / "run_config.json", {**config, "case_ids": [case["id"] for case in cases],
        "generator_implementation": "qcheck-gen-v1"})
    print("Run directory:", run_dir, flush=True)
    with (run_dir / "results.csv").open("w", newline="", encoding="utf-8") as handle:
        writer = None
        for case in cases:
            result = run_case(case, manifest.parent, run_dir / case["id"], config, resources)
            if writer is None:
                writer = csv.DictWriter(handle, fieldnames=list(result))
                writer.writeheader()
            writer.writerow({key: json.dumps(value) if isinstance(value, (dict, list)) else value
                             for key, value in result.items()})
            handle.flush()
            print(f"{case['id']}: {result['status']} ({result['stage']})", flush=True)
    dump(run_dir / "batch_summary.json", {
        "case_count": len(cases), "batch_seconds": time.monotonic() - started})
    return 0


if __name__ == "__main__":
    sys.exit(main())

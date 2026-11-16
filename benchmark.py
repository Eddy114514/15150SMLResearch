#!/usr/bin/env python3
"""Prepare specification prompts and run their model translations and tests."""
import argparse
import json
from pathlib import Path
import subprocess
import time
import uuid

import run
import sml

ROOT = run.ROOT
PREPARED = ROOT / "benchmark/prepared"
VERSIONS = ("original", "optimized", "degraded")


def read(path):
    return json.loads(path.read_text(encoding="utf-8"))


def load_plan(*, case_id=None):
    """Add experiment settings and scoring data to the ordinary pipeline plan."""
    config, cases, plan = run.load_plan(case_id=case_id, group="hw", property_source="model")
    config["benchmark"] = {**read(ROOT / "benchmark/config.json"), "models": config["models"]}
    plan["specifications"] = read(ROOT / "benchmark/specifications.json")
    plan["benchmark_metadata"] = read(ROOT / "benchmark/metadata.json")
    for ident, node in plan["nodes"].items():
        plan["specifications"][ident]["original"]["text"] = node["contract"]
    return config, cases, plan


def specification_node(node, specification):
    """The selected wording is public; expected outcomes stay in scoring."""
    return {**node, "contract": specification["text"]}


def prepare(config, plan):
    if plan["errors"]:
        raise RuntimeError("Cannot schedule callable helpers: " + "; ".join(
            error["message"] for errors in plan["errors"].values() for error in errors))
    session = ROOT / config["output_dir"] / ("benchmark-prepare-" + uuid.uuid4().hex[:10])
    session.mkdir(parents=True)
    helpers = {}
    helper_cases = {dependency for node in plan["nodes"].values() for dependency in node["dependency_order"]}
    for ident in plan["order"]:
        if ident not in helper_cases:
            continue
        node = plan["nodes"][ident]
        result = run.run_case(node, session / ident, config,
            helpers=run.provided_helpers(node, helpers),
            dependencies=run.runtime_dependencies(ident, plan, helpers), property_source="manual")
        helpers[ident] = result
        run.dump(session / ident / "result.json", result)
        if not run.admitted(result):
            raise RuntimeError(f"Callable helper {ident}: {result['status']}; see {session / ident}")
        print(f"Helper {ident}: {result['status']}", flush=True)
    run.dump(session / "helper_results.json", helpers)

    for version in VERSIONS:
        for ident in plan["order"]:
            node = plan["nodes"][ident]
            entry = plan["specifications"][ident][version]
            directory = session / "prompts" / version / ident
            directory.mkdir(parents=True)
            messages = run.prompt_messages(node["case"], entry["text"], run.provided_helpers(node, helpers))
            run.dump(directory / "messages.json", messages)
    prepared = {"prepared_at": run.now(), "session": str(session),
        "case_ids": list(plan["order"]), "versions": list(VERSIONS),
        "prompts": str(session / "prompts"),
        "helpers": str(session / "helper_results.json"),
        "models": config["benchmark"]["models"],
        "generation_seeds": config["benchmark"]["generation_seeds"]}
    PREPARED.mkdir(parents=True, exist_ok=True)
    run.dump(PREPARED / "plan.json", prepared)
    count = len(prepared["case_ids"]) * len(VERSIONS)
    print(f"Prepared {count} specification prompts; "
          f"{count * len(prepared['generation_seeds'])} trials/model; plan: {PREPARED / 'plan.json'}", flush=True)
    return 0


def attempt_metrics(record):
    execution = record.get("execution") or {}
    attempts = (execution.get("preparation") or {}).get("attempts", [])
    initial = attempts[0] if attempts else {}
    compiled = initial.get("compile", {}).get("status")
    initial_ok = compiled == "compiled" if compiled in ("compiled", "compile_error") else None
    semantic = record.get("semantic") or {}
    semantic_pass = semantic.get("status") == "passed_semantic_checks"
    expected = record["expected_status"]
    executable = expected == "ok"
    actual = attempts[-1]["status"] if attempts else None
    pbt = execution.get("pbt")
    pbt_pass = run.admitted(execution) if pbt is not None else None
    return {"parseable": initial["status"] in ("ok", "ambiguous", "unsupported") if initial else None,
            "initial_compile_ok": initial_ok if executable else None,
            "initial_translation_faithful": initial_ok is True and semantic_pass if executable else None,
            "final_translation_faithful": semantic_pass if executable else None,
            "refusal_status_match": actual == expected if not executable and actual is not None else None,
            "reason_review_pending": not executable and actual in ("ambiguous", "unsupported"),
            "pbt_pass": pbt_pass}


def summarize(records, prepared):
    def rates(rows):
        denominator = len(rows)
        metrics = [attempt_metrics(row) for row in rows]
        keys = ("parseable", "initial_compile_ok", "initial_translation_faithful", "final_translation_faithful",
                "refusal_status_match", "pbt_pass")
        executable_count = sum(row["expected_status"] == "ok" for row in rows)
        refusal_count = denominator - executable_count
        denominators = {key: (refusal_count if key == "refusal_status_match" else
                              executable_count if key in ("initial_compile_ok", "initial_translation_faithful",
                                  "final_translation_faithful") else
                              sum(row["pbt_pass"] is not None for row in metrics) if key == "pbt_pass" else denominator)
                        for key in keys}
        requests = [request for row in rows
                    for request in ((row.get("execution") or {}).get("preparation") or {}).get("attempts", [])]
        parseable = sum(request["status"] in ("ok", "ambiguous", "unsupported") for request in requests)
        backend = {}
        for key in ("load_duration", "prompt_eval_duration", "eval_duration", "total_duration",
                    "prompt_eval_count", "eval_count", "prompt_eval_cached_count", "reasoning_tokens"):
            values = [request["backend_metrics"].get(key) for request in requests]
            backend[key] = sum(values) if values and all(value is not None for value in values) else None
        return {"denominator": denominator, "executable_denominator": executable_count,
            "refusal_denominator": refusal_count, "metric_denominators": denominators,
            "reason_review_pending": sum(row["reason_review_pending"] for row in metrics),
            **{key: {"count": sum(row[key] is True for row in metrics),
                      "rate": sum(row[key] is True for row in metrics) / denominators[key] if denominators[key] else None}
               for key in keys},
            "requests": {"count": len(requests), "parseable": parseable,
                "parseable_rate": parseable / len(requests) if requests else None,
                "client_seconds": sum(request["elapsed_seconds"] for request in requests),
                "backend": {**{key.replace("_duration", "_seconds"): value / 1e9 if value is not None else None
                               for key, value in backend.items() if key.endswith("_duration")},
                            **{key: value for key, value in backend.items() if key.endswith("_count")},
                            "reasoning_tokens": backend["reasoning_tokens"],
                            "tokens_per_second": backend["eval_count"] * 1e9 / backend["eval_duration"]
                                if backend["eval_duration"] and backend["eval_count"] is not None else None},
                "statuses": {status: sum(request["status"] == status for request in requests)
                             for status in sorted({request["status"] for request in requests})}},
            "complete": all(row["status"] not in ("not_run", "evaluating", "infrastructure_error") for row in rows),
            "statuses": {status: sum(row["status"] == status for row in rows)
                         for status in sorted({row["status"] for row in rows})}}
    return {"interpretation": "Executable fidelity uses specification labels, independently of implementation PBT. "
                "Refusal status matching does not validate its explanation; reason review remains pending. "
                "Finite checks are not a proof. Unrun attempts remain in their planned denominators.",
        "models": {label: rates([row for row in records if row["model_label"] == label]) for label in prepared["models"]},
        "versions": {label: {version: rates([row for row in records if row["model_label"] == label and
                                               row["version"] == version])
                             for version in prepared["versions"]} for label in prepared["models"]},
        "cases": {label: {ident: rates([row for row in records if row["model_label"] == label and row["case_id"] == ident])
                           for ident in prepared["case_ids"]} for label in prepared["models"]},
        "topics": {label: {topic: rates([row for row in records if row["model_label"] == label and row["topic"] == topic])
                            for topic in sorted({row["topic"] for row in records})} for label in prepared["models"]}}


def attempt_records(prepared, plan):
    """Keep every planned model/version/problem/repetition, including unrun trials."""
    return [{"case_id": ident, "version": version,
             "topic": plan["benchmark_metadata"][ident]["topic"],
             "expected_status": plan["specifications"][ident][version]["expected_status"],
             "model_label": label, "model": selected["name"], "repetition": index + 1,
             "generation_seed": None if selected.get("provider") in run.model.RESPONSES_PROVIDERS else seed,
             "status": "not_run"}
            for label, selected in prepared["models"].items() for version in prepared["versions"]
            for index, seed in enumerate(prepared["generation_seeds"])
            for ident in prepared["case_ids"]]


def run_benchmark(config, plan):
    prepared = read(PREPARED / "plan.json")
    config = {**config, "benchmark": {**config["benchmark"], "models": prepared["models"]}}
    helper_results = read(Path(prepared["helpers"]))
    specifications = plan["specifications"]
    run_dir = ROOT / config["output_dir"] / ("benchmark-" + uuid.uuid4().hex[:10])
    run_dir.mkdir(parents=True)
    print("Run directory:", run_dir, flush=True)
    run_record = {"started_at": run.now(), "config": config, "prepared_plan": prepared,
                  "complete": False}
    records = attempt_records(prepared, plan)

    started_run = time.monotonic()
    run.dump(run_dir / "run.json", run_record)
    try:
        for record in records:
            ident, label = record["case_id"], record["model_label"]
            version = record["version"]
            entry = specifications[ident][version]
            node = specification_node(plan["nodes"][ident], entry)
            helpers = run.provided_helpers(node, helper_results)
            dependencies = run.runtime_dependencies(ident, plan, helper_results)
            candidate_config = run.model.configure(config, prepared["models"][label], seed=record["generation_seed"])
            workdir = run_dir / label / version / ident / str(record["repetition"])
            workdir.parent.mkdir(parents=True, exist_ok=True)
            record["artifact_dir"] = str(workdir)
            started = time.monotonic()
            try:
                execution = run.run_case(node, workdir, candidate_config,
                    helpers=helpers, dependencies=dependencies, property_source="model", role="Candidate")
                record.update(execution=execution, status="evaluating", semantic=None)
                if candidate_config.get("provider") in run.model.RESPONSES_PROVIDERS and execution["status"] == "model_error":
                    raise RuntimeError(execution["preparation"]["attempts"][-1]["exception"])
                compiled = run.compilation(execution["preparation"])
                if record["expected_status"] == "ok" and compiled.get("status") == "compiled":
                    contradiction = entry.get("defect") == "contradiction"
                    semantic = sml.evaluate_semantics(node["case"], compiled,
                        workdir / "semantic", timeout=candidate_config["sml_timeout"], source=node["source_text"],
                        helpers=helpers, dependencies=dependencies, contradiction=contradiction)
                    record["semantic"] = semantic
                    run.dump(workdir / "semantic.json", semantic)
                semantic = record["semantic"]
                metrics = attempt_metrics(record)
                record["response_status"] = execution["preparation"]["attempts"][-1]["status"]
                if record["expected_status"] != "ok":
                    record["status"] = "refusal_status_match" if metrics["refusal_status_match"] else "refusal_status_mismatch"
                else:
                    record["status"] = "faithful" if metrics["final_translation_faithful"] else (
                        semantic["status"] if semantic else execution["status"])
            except (OSError, ValueError, RuntimeError, subprocess.SubprocessError, KeyboardInterrupt) as exc:
                # Preserve fixed denominators and fail visibly at the experiment boundary.
                record.update(status="infrastructure_error", infrastructure_exception=f"{type(exc).__name__}: {exc}")
                checkpoint = workdir / "translation.json"
                if "execution" not in record and checkpoint.is_file():
                    record["execution"] = {"status": "infrastructure_error", "pbt": None,
                                           "preparation": read(checkpoint)}
                raise
            finally:
                record["seconds"] = time.monotonic() - started
                if workdir.is_dir():
                    run.dump(workdir / "result.json", record)
            print(f"{label}/{version}/{ident}/{record['repetition']}: {record['status']}", flush=True)
        run_record["complete"] = True
    finally:
        run_record["seconds"] = time.monotonic() - started_run
        run_record["model_calls"] = sum(len(((item.get("execution") or {}).get("preparation") or {}).get("attempts", []))
                                        for item in records)
        rows = [{**{key: value for key, value in record.items() if key not in ("execution", "semantic")},
                 **attempt_metrics(record)} for record in records]
        run.dump(run_dir / "results.json", rows)
        run.write_csv(run_dir / "results.csv", rows)
        run.dump(run_dir / "summary.json", summarize(records, prepared))
        run.dump(run_dir / "run.json", run_record)

    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("prepare", "run"))
    parser.add_argument("--case", help="prepare a single homework case and its dependencies")
    parser.add_argument("--model", action="append", dest="models",
                        help="prepare only this configured model label; repeat to select several")
    args = parser.parse_args()
    if args.action == "run" and (args.case or args.models):
        parser.error("run uses the prepared selection; select cases and models during prepare")
    config, _, plan = load_plan(case_id=args.case)
    if args.models:
        config = {**config, "benchmark": {**config["benchmark"], "models": {
            label: config["benchmark"]["models"][label] for label in args.models}}}
    return prepare(config, plan) if args.action == "prepare" else run_benchmark(config, plan)


if __name__ == "__main__":
    raise SystemExit(main())

"""Prompt assembly and one Ollama HTTP/JSON request."""

import http.client
import json
import math
import time
import urllib.error
import urllib.request

SCHEMA = {
    "type": "object", "additionalProperties": False,
    "properties": {
        "status": {"type": "string", "enum": ["ok", "ambiguous", "unsupported"]},
        "requires_expr": {"type": ["string", "null"]},
        "ensures_expr": {"type": ["string", "null"]},
        "reason": {"type": "string"}},
    "required": ["status", "requires_expr", "ensures_expr", "reason"]}
HELPERS = {
    "Spec.sorted": "int list -> bool; true exactly when the list is nondecreasing; true on []",
    "Spec.sameMultiset": "int list * int list -> bool; equal element multiplicities, including duplicates",
    "List.foldl": "('a * 'b -> 'b) -> 'b -> 'a list -> 'b; visit left to right; callback takes the tuple (element, accumulator)",
    "List.foldr": "('a * 'b -> 'b) -> 'b -> 'a list -> 'b; visit right to left; callback takes the tuple (element, accumulator)",
    "List.all": "('a -> bool) -> 'a list -> bool; true if every element satisfies the predicate, including on []",
    "List.exists": "('a -> bool) -> 'a list -> bool; true if at least one element satisfies the predicate",
    "Int.min": "int * int -> int; takes one tuple (x, y), not two curried arguments",
    "Int.max": "int * int -> int; takes one tuple (x, y), not two curried arguments",
    "Int.minInt": "int option; SOME lowerBound on SML/NJ; valOf Int.minInt has type int",
    "Int.maxInt": "int option; SOME upperBound on SML/NJ; valOf Int.maxInt has type int",
    "pure_basis": "List.length, List.rev, List.all, List.exists, List.null, List.hd, List.tl, List.map, List.filter, List.foldl, List.foldr, List.concat, List.nth, List.take, List.drop; Int.abs, Int.minInt, Int.maxInt, Int.min, Int.max, Int.compare; arithmetic, ordered equality, comparisons, if/case, andalso/orelse, tuples, lists, lambdas, local pure let expressions. SML machine integers, not unbounded mathematical integers."}


def build_task_data(case, contract):
    """Keep implementation and research data out of the translation request."""
    target = {key: case[key] for key in
              ("entrypoint", "input_type", "output_type", "input_pattern")}
    target["contract"] = contract
    return {"target": target, "helpers": HELPERS, "output_schema": SCHEMA}


def initial_messages(task_data, translate_prompt):
    return [{"role": "system", "content": translate_prompt},
            {"role": "user", "content": json.dumps(task_data, ensure_ascii=False)}]


def repair_messages(messages, task_data, first_json, diagnostics, repair_prompt):
    data = {**task_data,
            "predicate_compile_diagnostics": {"stdout": diagnostics, "stderr": ""}}
    return messages + [
        {"role": "assistant", "content": first_json},
        {"role": "user", "content": repair_prompt + "\n\n" + json.dumps(data, ensure_ascii=False)},
    ]


def extract_metrics(envelope):
    """Keep Ollama nanosecond counters distinct from client wall-clock time."""
    durations = ("load_duration", "prompt_eval_duration", "eval_duration", "total_duration")
    counts = ("prompt_eval_count", "eval_count", "prompt_eval_cached_count")
    metrics = {key: envelope.get(key) for key in durations + counts}
    for key in durations:
        value = metrics[key]
        metrics[key + "_seconds"] = (
            value / 1e9 if type(value) in (int, float) and math.isfinite(value) and value >= 0
            else None)
    count, seconds = metrics["eval_count"], metrics["eval_duration_seconds"]
    metrics["decode_tokens_per_second"] = (
        count / seconds if type(count) in (int, float) and math.isfinite(count)
        and count >= 0 and seconds is not None and seconds > 0 else None)
    return metrics


def call_ollama(messages, *, model_name, ollama_url, options, timeout, think=None,
                keep_alive=None):
    """Return one response or the existing network/JSON failure classification."""
    payload = {"model": model_name, "messages": messages, "format": SCHEMA,
               "stream": False, "options": options}
    if think is not None:
        payload["think"] = think
    if keep_alive is not None:
        payload["keep_alive"] = keep_alive
    request = urllib.request.Request(ollama_url.rstrip("/") + "/api/chat",
        data=json.dumps(payload).encode(), headers={"Content-Type": "application/json"})
    result = {"status": None, "request": payload, "raw_response": None,
              "raw_content": None, "predicates": None, "exception": None,
              "done": None, "done_reason": None, "elapsed_seconds": 0.0,
              "http_timeout": False, "http_status": None, "request_timeout_seconds": timeout,
              "backend_metrics": extract_metrics({})}
    started = time.monotonic()
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            result["http_status"] = response.status
            result["raw_response"] = response.read().decode("utf-8")
        envelope = json.loads(result["raw_response"])
        if not isinstance(envelope, dict):
            raise ValueError("model response envelope must be an object")
        result["backend_metrics"] = extract_metrics(envelope)
        result.update(done=envelope["done"], done_reason=envelope.get("done_reason"))
        result["raw_content"] = envelope["message"]["content"]
        if result["done_reason"] == "length":
            raise ValueError("model output budget exhausted")
        if result["done"] is not True:
            raise ValueError("model response did not finish (done is not true)")
        value = json.loads(result["raw_content"])
        if value["status"] not in ("ok", "ambiguous", "unsupported"):
            raise ValueError("unknown model status")
        if value["status"] == "ok" and any(
                not isinstance(value[key], str) or not value[key].strip()
                for key in ("requires_expr", "ensures_expr")):
            raise ValueError("ok requires two nonempty predicate strings")
        result["status"] = value["status"]
        result["predicates"] = value
    except (urllib.error.URLError, TimeoutError, ConnectionError, http.client.HTTPException) as exc:
        result["status"] = "model_error"
        result["exception"] = str(exc)
        result["http_timeout"] = isinstance(exc, TimeoutError) or isinstance(
            getattr(exc, "reason", None), TimeoutError)
        if isinstance(exc, urllib.error.HTTPError):
            result["http_status"] = exc.code
    except (ValueError, TypeError, KeyError) as exc:
        result["status"] = "invalid_model_output"
        result["exception"] = str(exc)
    finally:
        result["elapsed_seconds"] = time.monotonic() - started
    return result

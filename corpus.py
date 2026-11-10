"""Resolve task sources, explicit helper dependencies and capability context."""

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SPECIFICATIONS = ROOT / "benchmark/specifications.json"
FIELDS = ("entrypoint", "input_type", "output_type", "input_pattern")
_TASK_MARKER = re.compile(
    r"(?m)^[ \t]*\(\*[ \t]*@(solution|manual)\b([^\r\n]*?)\*\)[ \t]*(?:\r?\n|$)")


def split_task_file(text):
    """Split reserved, standalone task markers without parsing SML.

    Return the unchanged text and None for legacy files. A combined file has
    one @solution followed by one or more @manual CASE_ID blocks. A provenance
    preamble stays outside the runtime solution slice.
    """
    markers = list(_TASK_MARKER.finditer(text))
    if not markers:
        return text, None
    solution = text[markers[0].end():markers[1].start()]
    manuals = {}
    for index, marker in enumerate(markers[1:], start=1):
        ident = marker[2].strip()
        end = markers[index + 1].start() if index + 1 < len(markers) else len(text)
        manuals[ident] = text[marker.end():end]
    return solution, manuals


def extract_contract(source_text, contract_id):
    """Read the marked comment from the project's fixed source format."""
    pattern = rf"\(\*\s*@contract\s+{re.escape(contract_id)}\s.*?\*\)"
    match = re.search(pattern, source_text, re.DOTALL)
    return match.group(0)


def _resolve_context(case, catalog, card_cache):
    identifiers = case["interfaces"]
    cards, shared = [], []
    for ident in dict.fromkeys(identifiers):
        entry = catalog[ident]
        if ident not in card_cache:
            path = ROOT / "interfaces" / entry["file"]
            card_cache[ident] = {"id": ident, "text": path.read_text(encoding="utf-8")}
        cards.append(card_cache[ident])
        if "support_cm" in entry:
            shared.append(str((ROOT / entry["support_cm"]).resolve()))
    shared = list(dict.fromkeys(shared))
    runtime = case.get("runtime_support_cm", [])
    runtime = [runtime] if isinstance(runtime, str) else runtime
    case["_context"] = {
        "interface_context": cards, "support_libraries": shared,
        "runtime_support_libraries": list(dict.fromkeys(
            [*shared, *(str((ROOT / path).resolve()) for path in runtime)])),
    }


def plan(cases, roots, tasks_dir, *, property_source="auto"):
    """Read once, schedule explicit helpers first, and resolve runtime context."""
    cases_by_id = {case["id"]: case for case in cases}
    paths = {case["id"]: (Path(tasks_dir) / case["source"]).resolve() for case in cases}
    specifications = json.loads(SPECIFICATIONS.read_text(encoding="utf-8"))
    result = {"order": [], "nodes": {}, "errors": {}, "specifications": specifications,
              "roots": list(dict.fromkeys(case["id"] for case in roots))}
    files, sources, state, stack = {}, {}, {}, []

    def error(ident, code, message, **details):
        result["errors"].setdefault(ident, []).append({"code": code, "message": message, **details})

    def read_file(path):
        if path not in files:
            text = path.read_text(encoding="utf-8")
            files[path] = (text, *split_task_file(text))
        return files[path]

    def source_info(ident):
        if ident not in sources:
            case = cases_by_id[ident]
            _, solution, sections = read_file(paths[ident])
            source = {"source_text": solution, "contract": None}
            if "contract_file" in case:
                text, _, sections = read_file((ROOT / case["contract_file"]).resolve())
                source["manual_text"] = text if sections is None else sections[ident]
            elif sections is not None and ident in sections:
                source["manual_text"] = sections[ident]
            if ident in specifications:
                source["contract"] = specifications[ident]["original"]["text"]
            else:
                source["contract"] = extract_contract(solution, case["contract_id"])
            sources[ident] = source
        return sources[ident]

    def visit(ident):
        if state.get(ident) == "done":
            return
        if state.get(ident) == "active":
            cycle = stack[stack.index(ident):] + [ident]
            for member in cycle[:-1]:
                error(member, "cyclic_dependency", "Contract dependency cycle: " + " -> ".join(cycle),
                      path=cycle)
            return
        case = cases_by_id[ident]
        dependencies = case.get("helpers", [])
        node = {"case": case, **source_info(ident),
                "dependencies": list(dict.fromkeys(dependencies)), "helpers": []}
        node["property_source"] = ("manual" if "manual_text" in node else "model") \
            if property_source == "auto" else property_source
        result["nodes"][ident] = node
        state[ident] = "active"
        stack.append(ident)
        for dependency in node["dependencies"]:
            helper = cases_by_id[dependency]
            name = helper["entrypoint"]
            if not helper.get("enabled", True):
                error(ident, "excluded_helper", f"Helper {dependency} is excluded from testing",
                      dependency=dependency)
                continue
            visit(dependency)
            node["helpers"].append({
                "case_id": dependency, "binding_name": name, "callable_name": "Helpers." + name,
                "entrypoint": name, "input_type": helper["input_type"], "output_type": helper["output_type"],
                "signature": f"({helper['input_type']}) -> ({helper['output_type']})",
                "contract": source_info(dependency)["contract"]})
        stack.pop()
        state[ident] = "done"
        result["order"].append(ident)

    for ident in result["roots"]:
        visit(ident)
    catalog = json.loads((ROOT / "interfaces/index.json").read_text(encoding="utf-8"))
    card_cache = {}
    for node in result["nodes"].values():
        _resolve_context(node["case"], catalog, card_cache)
    for ident, node in result["nodes"].items():
        for helper in node["helpers"]:
            helper["_context"] = result["nodes"][helper["case_id"]]["case"]["_context"]
        needed, pending = set(), list(node["dependencies"])
        while pending:
            dependency = pending.pop()
            if dependency not in needed and dependency in result["nodes"] and dependency != ident:
                needed.add(dependency)
                pending.extend(result["nodes"][dependency]["dependencies"])
        node["dependency_order"] = [dependency for dependency in result["order"] if dependency in needed]
    return result

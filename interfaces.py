"""Read the index and the interface cards explicitly listed by each case."""
import json
from pathlib import Path


def load(root, config):
    """Read only the index; resolve card paths relative to its directory."""
    path = (Path(root) / config["interfaces"]["index"]).resolve()
    index = json.loads(path.read_text(encoding="utf-8"))
    return {ident: (path.parent / filename).resolve()
            for ident, filename in index.items()}


def select(case, catalog):
    """Read each selected card once, preserving the case's first-occurrence order."""
    case_id = case["id"]
    if "interfaces" not in case:
        raise ValueError(f"Case {case_id}: missing interfaces field")
    identifiers = case["interfaces"]
    if not isinstance(identifiers, list):
        raise ValueError(f"Case {case_id}: interfaces must be a list of interface IDs")
    cards, seen = [], set()
    for ident in identifiers:
        if not isinstance(ident, str):
            raise ValueError(f"Case {case_id}: invalid interface ID {ident!r}; expected a string")
        if ident in seen:
            continue
        if ident not in catalog:
            raise ValueError(f"Case {case_id}: unknown interface ID {ident!r}")
        path = catalog[ident]
        if not path.is_file():
            raise FileNotFoundError(f"Case {case_id}: interface {ident!r} file not found: {path}")
        cards.append({"id": ident, "text": path.read_text(encoding="utf-8")})
        seen.add(ident)
    return cards

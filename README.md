# SML Contracts to QCheck/PBT

Marked SML contract + task interface list → Ollama predicates → SML compilation → QCheck generation and testing → saved results.

The model receives the original target contract, types, selected interface cards and directly referenced helpers that passed their independent checks in this run. Implementations and test answers are excluded. Generated predicate functors compile separately from the target; the runtime supplies only the admitted helpers. An error in a generated predicate allows one repair using the same conversation, failed JSON and compiler diagnostics, without changing its helper environment.

## Run

Use the configured WSL, SML/NJ, and Ollama environment:

```bash
cd /home/SMLResearch/15150SMLResearch
python3 run.py                               # All registered cases
python3 run.py --case sublist_sum            # One case
python3 run.py --case list_max
python3 run.py --file tasks/sublist_sum/sublist_sum.sml
python3 run.py --file tasks/all_even/all_even.sml  # Helper first, then main
python3 run.py --case all_even                   # Includes its helper dependency closure
```

Current cases: `flatten`, `isprime`, `sublist_sum`, `list_max`, `is_even`, `all_even`, `tree_is_leaf`, plus five Sequence cases: `seq_reverse_int`, `seq_reverse_bool`, `seq_flatten_int`, `seq_leaf_flags`, `list_to_seq`. Choose either `--case` or `--file`; source files must be registered in the manifest. These options select root cases. Their contract dependencies run first, with each case and concrete type instance checked only once in the run.

Edit [config.json](config.json) for the model, seed, sample counts, timeouts, and paths. Defaults: `qwen3.8:27b-q4_K_M` with `think: "low"`, 1,000 valid samples, 10,000 candidates, 600-second model timeout, and 30-second SML timeout. Runtime settings have no CLI overrides.

Set `model`, `model_options`, and the root-level `think` in that same file to switch models. Omit `think` or use `null` for the backend default; `false` explicitly disables thinking, while `true` or a backend-supported level string enables it. Initial and repair requests use the same settings. Only the final `message.content` is parsed as JSON; thinking stays in the raw response and is not replayed during repair. Output truncation is recorded as a failure. Larger models may use both CPU and GPU memory; download size does not establish VRAM requirements, and enabling thinking does not establish translation correctness.

Root-level `keep_alive` controls Ollama residency for both initial and repair requests (default: `"15m"`). Omit it or use `null` to retain the backend default; numeric `0` is sent and unloads after the request. Longer residency can avoid repeated loading between runs; it does not increase generation throughput.

Local configuration, contract markers, and paths are trusted. Source implementations are assumed to pass syntax checking. Ordinary local errors stop the command.

## Task Interfaces

Every case in [tasks/manifest.json](tasks/manifest.json) must explicitly provide an `interfaces` list. The existing `is_even` case uses `"interfaces": ["basis.integer"]`; `all_even` independently uses `["spec", "basis.integer"]`. Edit the target case's list, then run its existing `--case` or `--file` command.

To add documentation: write a short English card in `interfaces/`, register its ID and relative filename in [interfaces/index.json](interfaces/index.json), and put that ID in the target case's `interfaces` list. The root [config.json](config.json) specifies only the index location. Card paths resolve relative to the index, independently of the launch directory.

Cards load in the task's order; duplicate IDs keep their first occurrence. `[]` supplies no cards. Only selected files are read; discovering a helper does not add interface cards to its caller. Each helper uses its own explicit list during its independent check. Missing lists, unknown IDs and missing selected files are configuration errors identifying the task and offending ID/path. Selection supplies documentation; it does not restrict SML names or change the compiler environment.

Basis List/Integer (including `IntInf`) and the small trusted `Spec` library are available at runtime. `Spec` distinguishes list equality, set-like subset and multiset equality; its interval quantifiers short-circuit without building lists, but can still take linear time. These libraries are separate from student helpers, whose use in generated predicates requires the independent checks below.

The Sequence card covers all **36 public functions**, types, exception and views. The user-supplied [Sequence runtime](sequence/README.md) is now loaded through `sequence/sources.cm` and the task's shared support CM. It uses an opaque ArraySlice representation, with generic generation/display adapters and five registered examples. Two integration fixes expose the existing `cons` operation and make extreme invalid `drop` indices raise `Range`. This runtime is sequential; the PDF's parallel work/span is not an execution guarantee. SET still has documentation only. Selecting a card supplies text; its library must separately be declared in `support_cm`.

## Add a Task

Create `tasks/my_task.sml`:

```sml
(* @contract countElements
 * countElements : int list -> int
 * REQUIRES: true
 * ENSURES: The result equals the number of elements in xs.
 *)
fun countElements (xs : int list) : int = List.length xs
```

Append this object to the `cases` array in [tasks/manifest.json](tasks/manifest.json):

```json
{
  "id": "count_elements",
  "source": "my_task.sml",
  "contract_id": "countElements",
  "entrypoint": "countElements",
  "input_type": "int list",
  "output_type": "int",
  "input_pattern": "xs",
  "generator": "int_list",
  "interfaces": ["basis.list"]
}
```

`source` is relative to the manifest directory. `contract_id` matches the comment marker; `entrypoint` names the function; `input_pattern` binds the variables used in the contract. Then run `python3 run.py --case count_elements`. This example is a template.

Register each public helper and main function as a separate case, as in [all_even.sml](tasks/all_even/all_even.sml). Keep both implementations in their original source; the contract reference determines the dependency. No manual `context_contracts` list, TaskSpec module or copied helper body is needed. An explicit lambda entrypoint may still adapt a curried target: the harness applies `(entrypoint) input`. Such an adapter is not automatically an injectable helper signature.

| Input type | Generator | Input pattern |
|---|---|---|
| `int` | `int` | `x` |
| `int list` | `int_list` | `xs` |
| `int * int list` | `int_list_pair` | `(x, xs)` |
| `int list * int` | `list_int_pair` | `(L, n)` |
| `int list list` | `int_list_list` | `LL` |

The built-in route supports outputs `int`, `bool`, `int list`, `int list list`, and `int list option`. Other types use the SML data adapter below. QCheck generates fixed boundary inputs followed by random inputs: integers in -100..100 and list lengths in 0..20. For nested lists, both levels use that length range. Optional `"generator_options": {"sort_lists": true}` sorts random lists for `int_list`, `int_list_pair`, and `list_int_pair`, leaving boundary inputs unchanged.

## Check Helpers Before Their Callers

Write each helper's own contract and register its concrete input/output instance. In the caller's original `REQUIRES` or `ENSURES` text, name the function explicitly. The existing [all_even.sml](tasks/all_even/all_even.sml) already follows this convention:

```sml
(* @contract isEven
 * isEven : int -> bool
 * REQUIRES: true
 * ENSURES: The result is true if and only if x is divisible by 2.
 *)
fun isEven (x : int) : bool = x mod 2 = 0

(* @contract allEven
 * allEven : int list -> bool
 * REQUIRES: true
 * ENSURES: The result is true if and only if every element of xs is even,
 * in the sense defined by the isEven contract. For the empty list the result
 * is true.
 *)
fun allEven (xs : int list) : bool = List.all isEven xs
```

Run `python3 run.py --case all_even`. The runner reads the complete manifest, discovers `isEven` in the contract body, then translates and tests `is_even` before making the `all_even` model request. References match complete function names, not contract IDs or substrings such as `isEven2`. Signature headers, implementation bodies and references to the current function itself do not create dependency edges. This is a writing convention for explicit names, not general natural-language interpretation; phrases such as “the function above” do not identify a helper.

A helper is admitted only when its translation and predicate compilation succeed and its current QCheck result is `passed_sampled_tests`, reaching the configured positive valid-sample target without a failure or exception. A historical pass, successful compilation alone or insufficient valid inputs cannot admit it. Source text is read once for the run; shared and multi-level dependencies reuse this run's results. Restarting the command performs the checks again, with no cross-run pass cache.

The [Helper First evaluation](evaluation/helper_first_20260928/REPORT.md) records the real `--case all_even` model run separately from fixed-predicate scheduling and module-wiring checks.

The caller's request receives each admitted direct helper's source case, callable name, exact concrete signature, original contract and pass status. For this example it receives `Helpers.isEven : int -> bool`. The model must preserve that composition in its predicate, for example `result = List.all Helpers.isEven xs`, rather than reimplementing the helper. The current target is never its own oracle. A tested `int` instance does not authorize a polymorphic helper binding.

Each checker is an independently compiled functor with only its direct helper parameters. Runtime CM imports these predicate libraries and binds the actual functions from the unchanged Target source. Before a predicate calls a helper, its wrapper checks that helper's compiled `requires`; a false result raises `Spec.DependencyDomainViolation` naming the helper. This is a dependency-domain error, not a discarded sample or a student-main counterexample, and it does not start a model repair. Target's own internal helper calls remain unchanged. Linking in separate SML subprocesses does not share one live object across processes.

The predicate library imports the caller's and direct helpers' declared `support_cm` libraries so helper parameter types keep their existing shared identity. This does not add interface cards or load student implementations into predicate compilation; runtime imports the support libraries needed by the whole dependency closure.

If a dependency fails, the caller records `blocked_dependency` and its dependency status without calling its model or PBT. Cycles, a referenced declared helper without case metadata, ambiguous concrete instances and helper entry adapters without a determinable original calling signature also block affected callers; unrelated cases can continue. Ordinary engineering errors still stop directly. The first version is for accessible same-file functions; it does not discover arbitrary uncontracted functions, extract local closures or resolve cross-file/stateful helpers. Curried targets keep their existing adapter support.

## Connect Your Own Data Type

The runnable `tree_is_leaf` example checks whether the outermost constructor is `Tree.Leaf`. It uses these files:

- [Shared.sml](tasks/sequence/Shared.sml) defines `Tree.tree = Leaf of int | Node of tree * tree` once.
- [tree-support.cm](tasks/sequence/tree-support.cm) exports that shared type to both Contract and Target.
- [TreeData.sml](tasks/sequence/TreeData.sml) exports `TreeLeafData.genInput`, `edges`, `showInput`, and `showOutput`. It uses native QCheck `map`, `zip`, and `choose`; the printers emit Runner-compatible JSON. Random inputs are leaves or depth-one nodes, with a depth-two boundary example.
- [tree.sml](tasks/sequence/tree.sml) contains the student's function and its marked contract; [tree.md](interfaces/tree.md) describes only the public datatype.

The authoritative entry is in `tasks/manifest.json`:

```json
{
  "id": "tree_is_leaf",
  "source": "sequence/tree.sml",
  "contract_id": "treeIsLeaf",
  "entrypoint": "treeIsLeaf",
  "input_type": "Tree.tree",
  "output_type": "bool",
  "input_pattern": "tree",
  "interfaces": ["user.tree"],
  "support_cm": "tasks/sequence/tree-support.cm",
  "data_adapter": {
    "file": "tasks/sequence/TreeData.sml",
    "structure": "TreeLeafData"
  }
}
```

Run `python3 run.py --case tree_is_leaf` or `python3 run.py --file tasks/sequence/tree.sml`. For another type, supply its shared module/CM, a small data adapter and a contract, then register its card and case; no Python or Runner type branch is needed. A signature alone does not specify the target's behavior or input distribution.

`support_cm` is optional; its path and `data_adapter.file` resolve from the project root. `source` keeps its existing manifest-relative rule. Explicit adapters supply all four values and replace the old `generator`/`generator_options` fields. SML checks their types against Contract; Python performs no type inference. Only the input needs a generator; the output needs a printer. Configuration errors stop directly. Data, boundaries, student bodies and test answers do not enter predicate compilation or the prompt.

The reusable combinators are `Generators.sequence fromList (lengthGen, elementGen)` and `Runner.sequence toList showElement`. With a real library, pass `Seq.fromList` and `Seq.toList`. Sampling uses sequential `List.tabulate` before constructing the container because QCheck's callback updates RNG state. Nested lengths and recursive depth are explicit generation budgets, not changes to the contract.

[Sequence examples](tasks/sequence/README.md) cover int, bool, nested sequences, tree elements and list input with sequence output. All five are now in the single active manifest. Run `python3 run.py --case seq_leaf_flags` or `python3 run.py --file tasks/sequence/operations.sml`. Both predicate and runtime CM use `tasks/sequence/support.cm`, which shares the real Seq library and the Tree type. Data remains runtime-only. The former installation fragment was merged and removed.

This example trusts `Tree` as an input representation. If the data structure itself is under test, keep it inside Target and preserve an independent model: for example, generate a plain list of enqueue/dequeue operations, initialize a fresh queue per input, and compare returned observations with a list-based reference. Do not trust that same queue's `fromList`/`toList` as the answer. Public functions need their own contracts and cases; local types must be shared explicitly or tested through a public wrapper. No automatic datatype extraction or state-machine framework is provided.

## Read Results

Each run creates `runs/<run-id>/`:

- `run_config.json`: configuration, requested `root_case_ids`, planned `case_ids`, source snapshots and direct dependency map.
- `results.csv`: one summary row per case.
- `<case>/translation.json`: actual interface IDs, admitted helper metadata, model requests/responses and predicate compilation results, when translation was attempted.
- `<case>/inputs.json`: generated candidates, when input generation is reached.
- `<case>/result.json` and `log.txt`: final status, counts, counterexample or exception, diagnostics, `direct_dependencies`, `blocked_by`, `dependency_errors` and `provided_helpers`.
- `batch_summary.json`: requested roots, actual executed case IDs, added dependency cases, their results, model-call count and batch wall time.

Each translation attempt retains its actual request, raw response, request/completion timestamps, client `elapsed_seconds`, HTTP timeout flag, completion state, and `backend_metrics`. Backend durations retain their nanosecond values and have separate seconds conversions; missing metrics stay `null`. `model_seconds` remains the sum of translation/repair request times. `case_seconds` includes interface assembly, translation, compilation, and PBT. Source/contract IDs, direct dependencies, admitted helper names and concrete signatures, selected interfaces, character counts, repair count and final compilation are traceable; characters are not token estimates. Each case records `requested_root`, `model_calls`, `started_at` and `finished_at`. Blocked callers retain their blocking reasons and do not receive fabricated translation or passing-test records.

A false `requires` discards the input without calling the target. A false `ensures` records a counterexample. Passing requires reaching the valid-sample target with no failure; too few valid inputs means `insufficient_valid_inputs`. Translation failures, runtime exceptions, and timeouts are recorded separately.

Generated candidates can outnumber checked inputs. QCheck may repeat a failing input, so `target_calls` can exceed `accepted`; counterexamples are not minimized. Statistics left `null` after a timeout are unavailable, not zero.

Option outputs use `{"tag":"NONE"}` or `{"tag":"SOME","value":[...]}`; `null` means no recorded output.

**Check the generated predicates before interpreting a pass.** Compilation does not establish faithful translation, and finite QCheck samples can miss helper or caller errors. A caller using an admitted helper depends on that helper and both translations; `passed_sampled_tests` is evidence for this run's samples, not a proof over all inputs.

QCheck: [upstream](https://github.com/league/qcheck), commit `92a43445779e6098a79175b41bba76ab90667256`; [license](vendor/qcheck/LICENSE).

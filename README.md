# SML Contracts to QCheck/PBT

Student-written requires/ensures → faithful Boolean predicates → independent translation checks and implementation PBT. The specification, translation, and student implementation are three distinct objects; an implementation counterexample is not a translation failure.

The model receives the selected specification, types, selected interface cards and declared direct helpers that passed their independent checks in this run. Student implementations and evaluation answers are excluded. Generated predicate functors compile with selected shared types and trusted capabilities, separately from the student target; the runtime supplies admitted student helpers. An error in a generated predicate allows one repair using the same conversation, failed JSON and compiler diagnostics, without changing its helper environment.

Homework comparison preparation is separate from model execution:

```bash
python3 benchmark.py prepare --model DeepSeek-1017  # Prepare helpers and export prompts
python3 benchmark.py prepare --case hw_tails --model DeepSeek-1017
# Start model generation explicitly:
python3 benchmark.py run
```

See the [preparation report](docs/BENCHMARK_PREPARATION.md), [three specification versions](benchmark/specifications.json), and [prepared plan](benchmark/prepared/plan.json). The configured models are five Ollama models, GPT-Luna, GPT-Terra, and DeepSeek-1017. Repeat `--model LABEL` to select models. Without a selection, preparation includes all configured entries; `run` uses only the prepared selection.

Each selected model runs 31 cases × three specification versions × two repetitions = 186 initial requests, with at most one compiler repair each. The versions are `original` (verbatim source requirements), `optimized` (wording intended to clarify the original conditions), and `degraded` (documented ambiguity or contradiction). An explicit contradiction is translated faithfully; it is not automatically a refusal. Ollama seeds are 15001 and 15002. Hosted API repetitions use `generation_seed: null`; existing model-specific reasoning and root output budgets remain unchanged.

Both commands reuse root PBT settings (seed 150, 1,000 valid samples, 10,000 candidates, 30-second SML timeout). Preparation makes no network requests. Initial prompts and helper results are saved under a new `runs/benchmark-prepare-*` session; `benchmark/prepared/plan.json` points to that session. API setup is documented in [OPENAI.md](docs/OPENAI.md) and [DEEPSEEK.md](docs/DEEPSEEK.md). One API model has 186 initial requests, two have 372, three have 558.

To download the exact 7B model on another machine, run `ollama pull qwen2.5-coder:7b-instruct-q8_0` ([model tag](https://ollama.com/library/qwen2.5-coder:7b-instruct-q8_0), [Ollama CLI](https://docs.ollama.com/cli)). The local inventory already contains it. This download command does not start the benchmark.

For Colab GPU migration, use the [English installation plan](docs/COLAB.md) and [English Notebook](setup/colab.ipynb). [export_colab.py](setup/export_colab.py) packages the working tree, assignment dependencies and QCheck. Repeated `--model LABEL` arguments select GPU models without downloading weights or changing local API preparation. The Notebook installs dependencies, downloads the selected models, prepares the benchmark and backs up results to Drive. Formal generation is a separate step.

`corpus.plan` independently selects the specification and manual reference. Homework translation reads the original entry directly from `benchmark/specifications.json`, once during planning. The manifest no longer duplicates the specification, and manual comments never replace it. Basic examples use their source contract. `run.py --properties auto|manual|model` chooses how to obtain predicates: auto/manual use registered references, model translates the selected text. All 43 active cases have references, so the ordinary default makes no model calls. A student helper still needs successful PBT before it can be supplied to another task.

The manifest's optional `enabled` field defaults to true. Four homework cases currently have `enabled: false`: `hw_book_flip`, `hw_book_trace`, `hw_lazy_interleave`, and `hw_find_n`. Ordinary selection, benchmark preparation and regression tests all exclude them, including explicit `--case` selection. An excluded helper blocks its caller and is never scheduled. Their definitions, standards and existing failure evidence remain available. The active set contains 31 homework cases and 12 basic examples.

`run.load_plan` reads the configuration and manifest, selects enabled roots and invokes `corpus.plan`. Planning reads each source once, follows explicit manifest `helpers` IDs, resolves one interface index and one text copy per selected card, and computes each task's transitive `dependency_order` in global execution order. The same context supplies prompt cards and shared/runtime CM paths to export, translation, compilation and linking. Helper metadata shares its source task's context, and runtime assembly consumes the precomputed closure.

Preparation runs manual PBT only for callable student helpers and exports the selected prompts. Semantic scoring applies each generated predicate directly to fixed labelled inputs and outputs. It does not compile or recheck a manual oracle, check fixture coverage or input domains, or run calibration predicates. Contradictory variants use the existing requires labels and false ensures labels. Predicate compilation still excludes target implementations and fixtures.

Translation fidelity checks whether the candidate agrees with the selected specification on labelled inputs and outputs. It does not require the student implementation to pass PBT. Full specifications requiring unavailable observations (including complexity and infinite behavior) expect `unsupported`; their finite functional references remain ordinary regression checks and are not benchmark translation evidence. Expected `ambiguous`/`unsupported` responses are reported separately as status matches with the explanation pending human review.

Formal results preserve the complete model × version × case × repetition grid, including unrun rows. Reports give separate executable-translation, expected-refusal, and actual-PBT denominators, grouped by model, specification version, case and topic.

`run_case` returns one record containing `case_id`, `status`, `stage`, `preparation`, `pbt`, and `seconds`. Manual preparation holds its compilation result; model preparation holds its initial and optional repair attempts. `run.compilation` selects the manual compilation or the last model attempt containing one. Callers use these records directly. Formal attempts construct their prompt once through the common translation path. No semantic answers enter a repair.

## Run

Use the configured WSL, SML/NJ, and Ollama environment:

```bash
cd /home/SMLResearch/15150SMLResearch
python3 run.py                               # All 43 enabled cases, manual predicates
python3 run.py --case sublist_sum            # One manual case
python3 run.py --case list_max
python3 run.py --file tasks/sublist_sum/sublist_sum.sml
python3 run.py --group hw                    # All 31 enabled homework cases
python3 run.py --case hw_tails --properties manual
# Explicit model route, only when model execution is intended:
python3 run.py --case hw_tails --properties model
python3 run.py --case all_even --properties model # Translate helper, then caller
```

Edit [config.json](config.json) for the model, seed, sample counts, timeouts, and paths. Defaults: `qwen3.8:27b-q4_K_M` with `think: "low"`, 1,000 valid samples, 10,000 candidates, 600-second model timeout, and 30-second SML timeout. Use `--model LABEL` to select a configured benchmark model for an ordinary run; sampling and PBT budgets remain in config.json.

For the Ollama route, set `model`, `model_options`, and the root-level `think` in that same file to switch models. Omit `think` or use `null` for the backend default; `false` explicitly disables thinking, while `true` or a backend-supported level string enables it. Initial and repair requests use the same settings. Only the final `message.content` is parsed as JSON; thinking stays in the raw response and is not replayed during repair. Output truncation is recorded as a failure. Larger models may use both CPU and GPU memory; download size does not establish VRAM requirements, and enabling thinking does not establish translation correctness.

Root-level `keep_alive` controls Ollama residency for both initial and repair requests (default: `"15m"`). Omit it or use `null` to retain the backend default; numeric `0` is sent and unloads after the request. Longer residency can avoid repeated loading between runs; it does not increase generation throughput.

Local configuration, contract markers, interfaces and paths are trusted. Ordinary file access, lookup and compiler errors propagate directly. The pipeline does not preflight configuration, model access or dataset structure.

## Task Interfaces

To add documentation: write a short English card in `interfaces/`, register its ID and relative filename in [interfaces/index.json](interfaces/index.json), and put that ID in the target case's `interfaces` list. The index location is fixed at `interfaces/index.json`. Card paths resolve relative to the index, independently of the launch directory.

Cards load in the task's order; duplicate IDs keep their first occurrence. `[]` supplies no cards. Only selected files are read; declaring a helper does not add interface cards to its caller. Each helper uses its own explicit list during its independent check. Every index entry is an object such as `{"file": "homework/lazy.md", "support_cm": "tasks/hw/support/lazy/support.cm"}`; `support_cm` is an optional single CM path. The selected cards determine both prompt text and shared compilation dependencies. CM exports and functor parameters determine actual SML scope; card text is not a name filter.

Basis List/Integer (including `IntInf`) and the small trusted `Spec` library are available at runtime. `Spec` distinguishes list equality, set-like subset and multiset equality; its interval quantifiers short-circuit without building lists, but can still take linear time. These libraries are separate from student helpers, whose use in generated predicates requires the independent checks below.

The Sequence card covers all **36 public functions**, types, exception and views. Selecting `cmu150.sequence` loads the user-supplied [Sequence runtime](sequence/Seq.sml) through `sequence/sources.cm`; `user.tree` loads the single Tree definition through `tasks/sequence/tree-support.cm`. Sequence uses an opaque ArraySlice representation, generic generation/display adapters and five registered examples. Two integration fixes expose the existing `cons` operation and make extreme invalid `drop` indices raise `Range`. This runtime is sequential; the PDF's parallel work/span is not an execution guarantee. SET remains a documentation-only card without a runtime binding.

## Add a Task

Create `tasks/my_task.sml`:

```sml
(* @solution *)
fun countElements (xs : int list) : int = List.length xs

(* @manual count_elements *)
(* @contract countElements
 * countElements : int list -> int
 * REQUIRES: true
 * ENSURES: The result equals the number of elements in xs.
 *)
functor ManualContract (Helpers : sig end) = struct
  type input = int list
  type output = int
  fun requires (xs : input) = true
  fun ensures (xs : input) (result : output) = result = List.length xs
end
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
  "data_adapter": {
    "file": "tasks/basic/Data.sml",
    "structure": "BasicData.ListMax"
  },
  "interfaces": ["basis.list"]
}
```

`source` is relative to the manifest directory. `contract_id` matches the comment marker; `entrypoint` names the function; `input_pattern` binds the variables used in the contract. Run `python3 run.py --case count_elements` to use the manual predicates, or add `--properties model` to translate that same contract description. This example is a template.

Register each public helper and main function as a separate case, as in [all_even.sml](tasks/all_even/all_even.sml), and list helper case IDs in the caller's manifest `helpers` array. Keep both implementations in their original source. Contract wording describes behavior; it does not create dependency edges. An explicit lambda entrypoint may still adapt a curried target: the harness applies `(entrypoint) input`. Such an adapter is not an injectable helper signature.

Every case selects a data adapter exporting `genInput`, `edges`, `showInput`, and `showOutput`. This example reuses `BasicData.ListMax` because it generates `int list` inputs and prints `int` outputs; the adapter does not encode the target's behavior. [BasicData](tasks/basic/Data.sml) also supplies `Flatten`, `IntBool`, `SublistSum`, and `AllEven`. These adapters preserve the basic tasks' fixed boundary inputs followed by random inputs: integers in -100..100 and list lengths in 0..20, at both levels for nested lists. Choose or write an adapter with the input distribution and printers your task requires.

## Check Helpers Before Their Callers

Write each helper's own contract, register its concrete input/output instance, and declare its case ID in the caller's manifest entry. The current dependencies are:

| Caller case | Manifest field | Predicate binding |
|---|---|---|
| `all_even` | `"helpers": ["is_even"]` | `Helpers.isEven : int -> bool` |
| `hw_tails` | `"helpers": ["hw_heads"]` | `Helpers.heads : int * int list -> int` |

Omitting `helpers` means an empty list. IDs retain their declared order, with duplicates removed. Contract text and implementation bodies are not scanned for helper names. The description should still explain how a declared helper contributes to the caller's behavior, as in [all_even.sml](tasks/all_even/all_even.sml).

Run `python3 run.py --case all_even` to check `is_even` and then `all_even` with their manual predicates. To exercise translation, use `python3 run.py --case all_even --properties model`; the helper must pass before the caller's model request. Shared and multi-level dependencies reuse this run's results and the precomputed dependency order.

`run.admitted` accepts the current result's `passed_sampled_tests` status. Runner emits that status only after a complete, failure-free run reaches the configured positive valid-sample target; unsuccessful compilation never reaches Runner. This invariant supplies the admission decision without repeating its counter checks in Python. A historical pass, compilation alone or insufficient valid inputs cannot admit a helper. Restarting the command performs the checks again, with no cross-run pass cache.

The [Helper First evaluation](evaluation/helper_first_20260928/REPORT.md) is historical evidence of a real model run before the basic tasks had manual defaults. The current equivalent command explicitly includes `--properties model`.

The caller's request receives each admitted direct helper's source case, callable name, exact concrete signature, original contract and pass status. For this example it receives `Helpers.isEven : int -> bool`. The model must preserve that composition in its predicate, for example `result = List.all Helpers.isEven xs`, rather than reimplementing the helper. The current target is never its own oracle. A tested `int` instance does not authorize a polymorphic helper binding.

Each checker is an independently compiled functor with only its direct helper parameters. Names include the readable case ID: for example, `Contract__all_evenFn` for an ordinary contract and `Contract_Candidate_hw_tailsFn` for a benchmark candidate. Runtime CM imports these predicate libraries and binds the actual functions from the unchanged Target source. Before a predicate calls a helper, its wrapper checks that helper's compiled `requires`; a false result raises `Spec.DependencyDomainViolation` naming the helper. This is a dependency-domain error, not a discarded sample or a student-main counterexample, and it does not start a model repair. Target's own internal helper calls remain unchanged. Linking in separate SML subprocesses does not share one live object across processes.

The predicate library imports shared CM libraries selected by the caller's and direct helpers' interface cards so helper parameter types keep their existing shared identity. This does not add helper cards to the caller's prompt or load student implementations into predicate compilation; runtime imports the libraries needed by the whole dependency closure.

If a dependency fails PBT, the caller records `blocked_dependency` without calling its model or PBT. Cycles and excluded helpers also block scheduling. Helpers bind to `Target.<entrypoint>` in the caller's source module, so task declarations must supply the corresponding callable and concrete types. SML compilation resolves type errors.

## Connect Your Own Data Type

The runnable `tree_is_leaf` example checks whether the outermost constructor is `Tree.Leaf`. It uses these files:

- [Shared.sml](tasks/sequence/Shared.sml) defines `Tree.tree = Leaf of int | Node of tree * tree` once.
- [tree-support.cm](tasks/sequence/tree-support.cm) exports that shared type to both Contract and Target.
- [TreeData.sml](tasks/sequence/TreeData.sml) exports `TreeLeafData.genInput`, `edges`, `showInput`, and `showOutput`. It selects values and depth for [TreeSupport](tasks/sequence/TreeSupport.sml), which shares QCheck construction and JSON display with the sequence-of-tree task. Random inputs are leaves or depth-one nodes, with a depth-two boundary example.
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
  "data_adapter": {
    "file": ["tasks/sequence/TreeSupport.sml", "tasks/sequence/TreeData.sml"],
    "structure": "TreeLeafData"
  }
}
```

Run `python3 run.py --case tree_is_leaf` or `python3 run.py --file tasks/sequence/tree.sml`. For another type, supply its shared module/CM, a small data adapter and a contract, then register its card and case; no Python or Runner type branch is needed. A signature alone does not specify the target's behavior or input distribution.

The `user.tree` index entry supplies `support_cm`. That path and `data_adapter.file` resolve from the project root; `source` remains manifest-relative. Every adapter supplies all four values. SML checks their types against Contract; Python performs no type inference. Only the input needs a generator; the output needs a printer. Configuration errors stop directly. Runtime data files and boundaries do not enter predicate compilation or the prompt. An interface's shared CM is visible to both predicate and runtime compilation, so keep Target-dependent code out of it.

`runtime_support_cm` supplies libraries needed only by the student implementation, such as Tracker and Find150 implementations. It is excluded from predicate compilation. Fixed trusted reference models belong in the selected capability's shared CM; manual standards, labelled examples and hidden counterexamples do not.

The reusable combinators are `Generators.sequence fromList (lengthGen, elementGen)` and `Runner.sequence toList showElement`. With a real library, pass `Seq.fromList` and `Seq.toList`. Sampling uses sequential `List.tabulate` before constructing the container because QCheck's callback updates RNG state. Nested lengths and recursive depth are explicit generation budgets, not changes to the contract.

[Sequence examples](tasks/sequence/Data.sml) cover int, bool, nested sequences, tree elements and list input with sequence output. All five are in the single active manifest. Run `python3 run.py --case seq_leaf_flags` or `python3 run.py --file tasks/sequence/operations.sml`. They select the real Seq library through its card. Only `seq_leaf_flags` also selects the Tree card; the other four declare Tree as a runtime dependency because the shared implementation and data file reference it. All routes use the same Tree definition. Data remains runtime-only, and the former combined `tasks/sequence/support.cm` has been removed.

This example trusts `Tree` as an input representation. If the data structure itself is under test, keep it inside Target and preserve an independent model: for example, generate a plain list of enqueue/dequeue operations, initialize a fresh queue per input, and compare returned observations with a list-based reference. Do not trust that same queue's `fromList`/`toList` as the answer. Public functions need their own contracts and cases; local types must be shared explicitly or tested through a public wrapper. No automatic datatype extraction or state-machine framework is provided.

## Reuse Support in a Handwritten Task

Keep the unchanged answer under `(* @solution *)` and a handwritten reference under `(* @manual CASE_ID *)`. `contract_file` is only for external references. Homework references and fixed labelled tests in `tasks/hw/evaluation/` describe the submitted conditions, including weak conditions. Register all three specification versions when adding a benchmark case.

Store specification text and provenance in `benchmark/specifications.json`. Only the selected contract, neutral representation description, budgets, declared helpers and capability cards enter the prompt. Other versions, expected refusals, defect labels, manual code and labelled test answers stay private.

Reuse the existing facilities before adding helpers:

| Facility | Existing callers and purpose |
|---|---|
| `Generators.sample`, `Generators.sequence`, QCheck combinators | Fixed edges followed by seeded samples; sequential container construction. Individual data adapters choose distributions and budgets. |
| `Generators.bind gen next` | Dependent generation without handling RNG state in Data: regex continuation length, CPS result count, Book cursor and matrix dimensions. |
| `Runner.list`, `pair (showLeft, showRight)`, `option`, `object`, `quote`, `sequence` | JSON display of printable inputs and observations. |
| [Affine](sml/Affine.sml) and [Affine.cm](sml/Affine.cm) | Encryption function payloads and lazy-tree mapping share the printable pair `Affine.t = int * int` and `Affine.apply`. Lazy-tree support does not depend on encryption. |
| [IntegerTreeData](tasks/hw/support/datatypes/TreeData.sml) | Symmetry and lazy-tree mapping share generation/display of `SymmetryInput.tree`. The caller supplies its value generator and node budget. |
| [TreeSupport](tasks/sequence/TreeSupport.sml) | The standalone tree task and sequence-of-tree task share bounded construction and display of `Tree.tree`. Each task chooses its value generator, depth and fixed edges. |
| [RegexTarget](tasks/hw/support/regex/RegexTarget.sml), [CpsTarget](tasks/hw/support/cps/CpsTarget.sml), [BookTarget](tasks/hw/support/book/BookTarget.sml) | Runtime-only conversion or observation shared within each task family. Each run binds these modules to its own `Target`. |
| [LazyObserve.fronts](tasks/hw/support/lazy/Observe.sml) | Cycle, interleave and BBS share prefix observation. `[]` means the budget ended; `[NONE]` records an exposed empty front. |

`target_wrapper` and `data_adapter.file` each accept either one path or an ordered list of paths. For example, the CPS cases use:

```json
"target_wrapper": [
  "tasks/hw/support/cps/CpsTarget.sml",
  "tasks/hw/support/cps/FindOneTarget.sml"
]
```

The existing runtime assembler concatenates the listed files into saved `target_wrapper.sml` and `data_adapter.sml` files. These files enter runtime CM only; no new loader or predicate dependency is introduced. For shared tree data, prepend `tasks/hw/support/datatypes/TreeData.sml` to the task's existing data file in the same way. Stable shared types and pure helpers use the selected interface's `support_cm`; generators and Target-dependent converters use these runtime lists. Declare each datatype once to preserve its type identity.

All adapters use one driver, `Generators.sample`, and `Runner.run`; Data never manages seeds, sample counts or execution loops. For dependent inputs, express the distribution with `Generators.bind`, for example `Generators.bind pagesGen (fn pages => QCheck.Gen.map (fn cursor => (pages,cursor)) (QCheck.Gen.range (0,List.length pages)))`. Use QCheck's `vector List.tabulate`, `option`, `zip` and `zip3` directly for ordinary containers and tuples.

Use `List.map f probes` directly for finite function observations; the task retains its probe order and result shape. Do not replace polynomial coefficient descriptions, valid equivalence relations or CPS-total predicates with arbitrary functions. Lazy and stateful adapters construct fresh runtime inputs per call. Their counters and exception outcomes keep their task-specific meanings: Book's `OutOfBounds`, Cnot control exceptions and encryption's ordinary `exn` values are not interchangeable.

Run `python3 tests/pbt_regression.py` for all 43 enabled cases with manual contracts and no model calls. The 31 homework cases also receive fixed-label scoring. The suite covers runtime assembly, predicate isolation and helper bindings. The tracker implementation is expected to produce a PBT counterexample against its literal condition; the other 42 cases pass. Excluded cases are not executed. `tests/book_adapter_checks.py` covers Book observation order and exception behavior.

Run `python3 tests/compiler_checks.py` for compilation and one-repair behavior using stubbed responses. Compiler errors are returned directly to the translation loop; there is no Python diagnostic-location filter. These checks make no real model requests.

## Read Results

An ordinary `run.py` invocation creates `runs/<run-id>/` (or the configured `output_dir`):

- `run.json` stores the configuration, selected property mode, start time, plan (`roots`, dependency-first `order`, planning `errors`), and direct dependency map. It starts with `complete: false`; completion adds the model-call count, and `seconds` records total elapsed time even when a local error stops execution.
- `<case>/result.json` stores `case_id`, terminal `status` and `stage`, `preparation`, `pbt`, and case `seconds`. Dependency-blocked cases also retain `blocked_by` and `dependency_errors`, with `preparation` and `pbt` set to `null`.
- `<case>/messages.json` stores the initial model conversation when translation is attempted. Its user message contains the task, admitted helper contracts and selected capability cards.
- `<case>/translation.json` checkpoints model preparation: each raw response is saved before compilation, then updated with its compile result. The final case result includes that preparation record.
- `<case>/inputs.json`, generated SML/CM files, and `log.txt` retain sampled inputs, the actual compiled programs and diagnostics for phases that ran.

Manual preparation has the form `{"mode": "manual", "compile": ...}`. Model preparation has the form `{"mode": "model", "attempts": [...]}`, with one initial attempt and at most one compiler repair. Each attempt records response status, `raw_response`, client `elapsed_seconds`, `http_timeout`, `done_reason`, `exception`, backend timing/token counters and, when reached, `compile`. Backend durations retain Ollama's nanosecond units; missing values stay `null`. Summary totals also stay `null` if any contributing request lacks that counter, rather than reporting a partial sum as a complete total. `run.compilation(preparation)` retrieves the compilation needed for linking and helper admission without a second top-level copy. Case `seconds` measures preparation and PBT; batch `seconds` also includes planning and context resolution.

Hosted API attempts additionally retain `api` metadata, including response ID, actual model, usage, status and HTTP status. `prompt_eval_count` maps to total API input tokens, `prompt_eval_cached_count` is the cached subset, and `eval_count` maps to total output tokens including `reasoning_tokens`. Do not add the subsets to their totals. Hosted APIs do not provide Ollama server durations, so those remain null. Credential, quota and transport errors stop an API benchmark with its partial results preserved; there are no hidden retries.

Initial messages are saved once. Full HTTP requests, a separate `raw_content`, and parsed-predicate copies are not stored; the raw response and generated contract SML preserve the model's output. Repair uses the initial conversation, its failed assistant response and compiler diagnostics. Diagnostics remain available in memory for repair and are persisted in `log.txt`, not repeated throughout JSON. Ordinary runs do not create `run_config.json`, `batch_summary.json`, `results.csv`, or source/contract snapshot copies.

Benchmark preparation writes `benchmark/prepared/plan.json` and a new `runs/benchmark-prepare-*` session containing prompts and callable-helper PBT results. The plan records selected cases, models, versions and repetition settings. PBT budgets and specification expectations come from the current configuration and dataset.

A run uses the selected plan and current task/specification files. Preparation does not copy source snapshots or store fingerprints, and execution does not compare source files, model contents or environment metadata. Re-run preparation when changing the selected cases or model list. Historical runs retain their recorded inputs and results.

A formal run saves `run.json` and per-attempt evidence under `<model>/<version>/<case>/<repetition>/`. Aggregate JSON/CSV rows include identifiers, status, artifact paths and the following metrics:

| Metric | Meaning |
|---|---|
| `parseable` | The initial response can be parsed into a supported status and the fields needed for execution. |
| `initial_compile_ok` | The initial predicate compiles before any repair. |
| `initial_translation_faithful` | Initial predicate compiles and agrees with the selected executable specification on the labels. |
| `final_translation_faithful` | Final predicate passes the selected specification labels, independently of PBT. |
| `refusal_status_match` | Response status matches the expected ambiguous/unsupported outcome; reason still needs review. |
| `pbt_pass` | Actual execution meets the same complete sampled-test criteria used to admit a helper. |

The benchmark writes `results.json`, `results.csv` and `summary.json` once in the outer `finally` block, on success or error, and updates `run.json` there. The fixed aggregate includes unrun rows after infrastructure failure. If compilation or execution raises before returning a case record, the exception boundary recovers the saved translation checkpoint so completed requests remain counted; the normal path consumes the in-memory record. A forced process termination can prevent this final aggregation, so inspect the per-attempt `result.json` files and translation checkpoints if aggregate files are absent or unfinished.

`summary.json` groups by model, version, case and topic. Executable translation rates exclude cases expecting refusal; refusal status matches exclude executable cases. PBT rates use only attempts that actually ran PBT. Unrun attempts stay in the appropriate translation/refusal denominator. A refusal status match is not verification of its explanation; `reason_review_pending` makes this limitation explicit. Repairs use compiler diagnostics only.

Semantic results contain checked and failed label counts, exceptions and the first counterexample. They describe the evaluated predicate only; no oracle, fixture-domain or coverage verification counters are produced.

Within `pbt`, a false `requires` discards an input without calling the target. A false `ensures` records a counterexample. Passing requires reaching the valid-sample target with no failure; too few valid inputs means `insufficient_valid_inputs`. Translation failures, runtime exceptions and timeouts have distinct statuses. Generated candidates can outnumber checked inputs. QCheck may repeat a failing input, so `target_calls` can exceed `accepted`; counterexamples are not minimized. Statistics left `null` after a timeout are unavailable, not zero.

Option outputs use `{"tag":"NONE"}` or `{"tag":"SOME","value":[...]}`; `null` means no recorded output.

**Check the generated predicates before interpreting a pass.** Compilation does not establish faithful translation, and finite QCheck samples can miss helper or caller errors. A caller using an admitted helper depends on that helper and its contract; `passed_sampled_tests` is evidence for this run's samples, not a proof over all inputs.

QCheck: [upstream](https://github.com/league/qcheck); [license](vendor/qcheck/LICENSE).

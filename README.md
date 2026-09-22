# SML Contracts to QCheck/PBT

Marked SML contract → Ollama predicates → SML compilation → QCheck generation and testing → saved results.

The initial model request contains only the current target contract, types, bindings, helpers, and output schema; no implementation or example answers are included. Generated predicates compile separately; a compilation error allows one repair attempt using the original instructions and target, the failed generated response, and compiler feedback.

## Run

Use the configured WSL, SML/NJ, and Ollama environment:

```bash
cd /home/SMLResearch/15150SMLResearch
python3 run.py                               # All registered cases
python3 run.py --case sublist_sum            # One case
python3 run.py --case list_max
python3 run.py --file tasks/sublist_sum/sublist_sum.sml
```

Current cases: `flatten`, `isprime`, `sublist_sum`, `list_max`. Choose either `--case` or `--file`; source files must be registered in the manifest.

Edit [config.json](config.json) for the model, seed, sample counts, timeouts, and paths. Defaults: `qwen3.8:27b-q4_K_M` with `think: "low"`, 1,000 valid samples, 10,000 candidates, 600-second model timeout, and 30-second SML timeout. Runtime settings have no CLI overrides.

Set `model`, `model_options`, and the root-level `think` in that same file to switch models. Omit `think` or use `null` for the backend default; `false` explicitly disables thinking, while `true` or a backend-supported level string enables it. Initial and repair requests use the same settings. Only the final `message.content` is parsed as JSON; thinking stays in the raw response and is not replayed during repair. Output truncation is recorded as a failure. Larger models may use both CPU and GPU memory; download size does not establish VRAM requirements, and enabling thinking does not establish translation correctness.

Optional root-level `keep_alive` controls Ollama residency for both initial and repair requests (for example, `"15m"`). Omit it or use `null` to retain the backend default; numeric `0` is sent and unloads after the request. Longer residency can avoid repeated loading between runs; it does not increase generation throughput.

Local configuration, contract markers, and paths are trusted. Source implementations are assumed to pass syntax checking. Ordinary local errors stop the command.

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
  "generator": "int_list"
}
```

`source` is relative to the manifest directory. `contract_id` matches the comment marker; `entrypoint` names the function; `input_pattern` binds the variables used in the contract. Then run `python3 run.py --case count_elements`. This example is a template.

| Input type | Generator | Input pattern |
|---|---|---|
| `int` | `int` | `x` |
| `int list` | `int_list` | `xs` |
| `int * int list` | `int_list_pair` | `(x, xs)` |
| `int list * int` | `list_int_pair` | `(L, n)` |
| `int list list` | `int_list_list` | `LL` |

Outputs support `int`, `bool`, `int list`, `int list list`, and `int list option`. QCheck generates fixed boundary inputs followed by random inputs: integers in -100..100 and list lengths in 0..20. For nested lists, both levels use that length range. Optional `"generator_options": {"sort_lists": true}` sorts random lists for `int_list`, `int_list_pair`, and `list_int_pair`, leaving boundary inputs unchanged.

## Read Results

Each run creates `runs/<run-id>/`:

- `run_config.json`: configuration and selected cases.
- `results.csv`: one summary row per case.
- `<case>/translation.json`: model responses and predicate compilation results.
- `<case>/inputs.json`: generated candidates, when input generation is reached.
- `<case>/result.json` and `log.txt`: final status, counts, counterexample or exception, and diagnostics.
- `batch_summary.json`: case count and batch wall time.

Each translation attempt retains its actual request, raw response, client `elapsed_seconds`, HTTP timeout flag, completion state, and `backend_metrics`. Backend durations retain their nanosecond values and have separate seconds conversions; missing metrics stay `null`. `model_seconds` remains the sum of client request times. `case_seconds` includes translation, compilation, and PBT; `repair_count` and `final_compile_ok` complement the first-compilation result.

A false `requires` discards the input without calling the target. A false `ensures` records a counterexample. Passing requires reaching the valid-sample target with no failure; too few valid inputs means `insufficient_valid_inputs`. Translation failures, runtime exceptions, and timeouts are recorded separately.

Generated candidates can outnumber checked inputs. QCheck may repeat a failing input, so `target_calls` can exceed `accepted`; counterexamples are not minimized. Statistics left `null` after a timeout are unavailable, not zero.

Option outputs use `{"tag":"NONE"}` or `{"tag":"SOME","value":[...]}`; `null` means no recorded output.

**Check the generated predicates before interpreting a pass.** Compilation does not establish faithful translation, and a weak predicate can miss implementation errors. Sampled agreement is not a correctness proof.

QCheck: [upstream](https://github.com/league/qcheck), commit `92a43445779e6098a79175b41bba76ab90667256`; [license](vendor/qcheck/LICENSE).

# SML Contracts to QCheck/PBT

Marked SML contract → Ollama predicates → SML compilation → QCheck generation and testing → saved results.

The initial model request contains only the current target contract, types, bindings, helpers, and output schema; no implementation or example answers are included. Generated predicates compile separately; a compilation error allows one repair attempt using the original instructions and target, the failed generated response, and compiler feedback.

## Run

Use the configured WSL, SML/NJ, and Ollama environment:

```bash
cd /home/SMLResearch/15150SMLResearch
python3 run.py                               # All registered cases
python3 run.py --case sublist_sum            # One case
python3 run.py --file tasks/sublist_sum/sublist_sum.sml
```

Current cases: `flatten`, `isprime`, `sublist_sum`. Choose either `--case` or `--file`; source files must be registered in the manifest.

Edit [config.json](config.json) for the model, seed, sample counts, timeouts, and paths. Defaults: 1,000 valid samples, 10,000 candidates, 180-second model timeout, and 30-second SML timeout. Runtime settings have no CLI overrides.

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

A false `requires` discards the input without calling the target. A false `ensures` records a counterexample. Passing requires reaching the valid-sample target with no failure; too few valid inputs means `insufficient_valid_inputs`. Translation failures, runtime exceptions, and timeouts are recorded separately.

Generated candidates can outnumber checked inputs. QCheck may repeat a failing input, so `target_calls` can exceed `accepted`; counterexamples are not minimized. Statistics left `null` after a timeout are unavailable, not zero.

Option outputs use `{"tag":"NONE"}` or `{"tag":"SOME","value":[...]}`; `null` means no recorded output.

**Check the generated predicates before interpreting a pass.** Compilation does not establish faithful translation, and a weak predicate can miss implementation errors. Sampled agreement is not a correctness proof.

QCheck: [upstream](https://github.com/league/qcheck), commit `92a43445779e6098a79175b41bba76ab90667256`; [license](vendor/qcheck/LICENSE).

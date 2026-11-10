(* Fixed independent semantic labels; never included in model prompts.
 * Every thunk constructs fresh values for each predicate evaluation. *)
structure Evaluation = struct
  type input = string list
  type output = bool

  val requiresCases : (string * (unit -> input) * bool) list = [
    ("valid-1", fn () => ["lambda","lambda","lambda"], true),
    ("valid-2", fn () => ["lambda","lambda"], true),
    ("valid-3", fn () => ["lambda","lambda","lambda","pointer"], true),
    ("valid-4", fn () => ["lambda lambda lambda"], true),
    ("valid-5", fn () => [], true)
  ]
  val ensuresCases : (string * (unit -> input * output) * bool) list = [
    ("threshold", fn () => (["lambda","lambda","lambda"], true), true),
    ("under-threshold", fn () => (["lambda","lambda"], false), true),
    ("forbidden-pointer", fn () => (["lambda","lambda","lambda","pointer"], false), true),
    ("exact-page-words", fn () => (["lambda lambda lambda"], false), true),
    ("empty", fn () => ([], false), true),
    ("wrong-threshold", fn () => (["lambda","lambda"], true), false),
    ("ignores-pointer", fn () => (["lambda","lambda","lambda","pointer"], true), false),
    ("false-negative", fn () => (["lambda","lambda","lambda"], false), false)
  ]
end

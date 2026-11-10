(* Fixed independent semantic labels; never included in model prompts.
 * Every thunk constructs fresh values for each predicate evaluation. *)
structure Evaluation = struct
  type input = CpsCase.predicate * CpsCase.tree
  type output = int option

  val requiresCases : (string * (unit -> input) * bool) list = [
    ("valid-1", fn () => (CpsCase.Any,CpsCase.Fork (CpsCase.Tip 3,CpsCase.Tip 4)), true),
    ("valid-2", fn () => (CpsCase.Even,CpsCase.Fork (CpsCase.Tip 3,CpsCase.Tip 4)), true),
    ("valid-3", fn () => (CpsCase.Positive,CpsCase.Tip ~1), true),
    ("valid-4", fn () => (CpsCase.Any,CpsCase.Tip 3), true)
  ]
  val ensuresCases : (string * (unit -> input * output) * bool) list = [
    ("leftmost", fn () => ((CpsCase.Any,CpsCase.Fork (CpsCase.Tip 3,CpsCase.Tip 4)), SOME 3), true),
    ("right-after-rejection", fn () => ((CpsCase.Even,CpsCase.Fork (CpsCase.Tip 3,CpsCase.Tip 4)), SOME 4), true),
    ("none", fn () => ((CpsCase.Positive,CpsCase.Tip ~1), NONE), true),
    ("wrong-leftmost", fn () => ((CpsCase.Any,CpsCase.Fork (CpsCase.Tip 3,CpsCase.Tip 4)), SOME 4), false),
    ("false-none", fn () => ((CpsCase.Any,CpsCase.Tip 3), NONE), false),
    ("predicate-rejected-leaf", fn () => ((CpsCase.Even,CpsCase.Fork (CpsCase.Tip 3,CpsCase.Tip 4)), SOME 3), false)
  ]
end

(* Fixed independent semantic labels; never included in model prompts.
 * Every thunk constructs fresh values for each predicate evaluation. *)
structure Evaluation = struct
  type input = CpsCase.predicate * CpsCase.equality * CpsCase.tree * int
  type output = int list option

  val requiresCases : (string * (unit -> input) * bool) list = [
    ("valid-1", fn () => (CpsCase.Any,CpsCase.Exact,CpsCase.Tip 1,0), true),
    ("valid-2", fn () => (CpsCase.Any,CpsCase.Exact,CpsCase.Fork (CpsCase.Tip 1,CpsCase.Tip 2),2), true),
    ("valid-3", fn () => (CpsCase.Any,CpsCase.Parity,CpsCase.Fork (CpsCase.Tip 1,CpsCase.Tip 3),2), true),
    ("valid-4", fn () => (CpsCase.Any,CpsCase.Exact,CpsCase.Tip 1,1), true),
    ("negative-count", fn () => (CpsCase.Any,CpsCase.Exact,CpsCase.Tip 1,~1), false)
  ]
  val ensuresCases : (string * (unit -> input * output) * bool) list = [
    ("zero", fn () => ((CpsCase.Any,CpsCase.Exact,CpsCase.Tip 1,0), SOME []), true),
    ("witness-a", fn () => ((CpsCase.Any,CpsCase.Exact,CpsCase.Fork (CpsCase.Tip 1,CpsCase.Tip 2),2), SOME [1,2]), true),
    ("witness-order-b", fn () => ((CpsCase.Any,CpsCase.Exact,CpsCase.Fork (CpsCase.Tip 1,CpsCase.Tip 2),2), SOME [2,1]), true),
    ("not-enough-classes", fn () => ((CpsCase.Any,CpsCase.Parity,CpsCase.Fork (CpsCase.Tip 1,CpsCase.Tip 3),2), NONE), true),
    ("duplicate-class", fn () => ((CpsCase.Any,CpsCase.Parity,CpsCase.Fork (CpsCase.Tip 1,CpsCase.Tip 3),2), SOME [1,3]), false),
    ("wrong-length", fn () => ((CpsCase.Any,CpsCase.Exact,CpsCase.Tip 1,1), SOME []), false),
    ("predicate-rejected-leaf", fn () => ((CpsCase.Even,CpsCase.Exact,CpsCase.Fork (CpsCase.Tip 3,CpsCase.Tip 4),1), SOME [3]), false),
    ("false-none", fn () => ((CpsCase.Any,CpsCase.Exact,CpsCase.Tip 1,1), NONE), false)
  ]
end

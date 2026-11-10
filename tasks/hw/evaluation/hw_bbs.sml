(* Fixed functional-projection labels, not validation of the full original
 * specification. Never included in model prompts.
 * Every thunk constructs fresh values for each predicate evaluation. *)
structure Evaluation = struct
  type input = int * int * int
  type output = int option list

  val requiresCases : (string * (unit -> input) * bool) list = [
    ("valid-1", fn () => (15,2,4), true),
    ("valid-2", fn () => (4,3,2), true),
    ("valid-3", fn () => (15,2,0), true),
    ("valid-4", fn () => (15,2,~2), true),
    ("valid-5", fn () => (15,2,2), true),
    ("valid-6", fn () => (15,2,3), true),
    ("prime-modulus", fn () => (7,2,2), false),
    ("three-prime-factors", fn () => (8,2,2), false),
    ("zero-modulus", fn () => (0,2,2), false)
  ]
  val ensuresCases : (string * (unit -> input * output) * bool) list = [
    ("recurrence", fn () => ((15,2,4), [SOME 4,SOME 1,SOME 1,SOME 1]), true),
    ("prime-square-modulus", fn () => ((4,3,2), [SOME 1,SOME 1]), true),
    ("zero-budget", fn () => ((15,2,0), []), true),
    ("negative-budget", fn () => ((15,2,~2), []), true),
    ("wrong-first", fn () => ((15,2,2), [SOME 2,SOME 4]), false),
    ("premature-end", fn () => ((15,2,2), [SOME 4,NONE]), false),
    ("empty-result-stream", fn () => ((15,2,2), [NONE]), false),
    ("wrong-recurrence", fn () => ((15,2,3), [SOME 4,SOME 1,SOME 2]), false)
  ]
end

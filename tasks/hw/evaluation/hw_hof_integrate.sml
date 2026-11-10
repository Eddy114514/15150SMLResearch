(* Fixed functional-projection labels, not validation of the full original
 * specification. Never included in model prompts.
 * Every thunk constructs fresh values for each predicate evaluation. *)
structure Evaluation = struct
  type input = int list * int list * int list
  type output = real list list

  val requiresCases : (string * (unit -> input) * bool) list = [
    ("valid-1", fn () => ([2,6],[3,~2],[~1,0,1,2,3]), true),
    ("valid-2", fn () => ([],[5],[0,1]), true),
    ("valid-3", fn () => ([1],[],[0]), true),
    ("valid-4", fn () => ([2,6],[3,~2],[0,1]), true),
    ("valid-5", fn () => ([2,6],[3],[2]), true),
    ("valid-6", fn () => ([2,6],[3,~2],[0]), true)
  ]
  val ensuresCases : (string * (unit -> input * output) * bool) list = [
    ("constants-and-probes", fn () => (([2,6],[3,~2],[~1,0,1,2,3]), [[0.0,3.0,2.0,3.0,0.0],[0.0,~2.0,2.0,3.0,0.0]]), true),
    ("zero-polynomial", fn () => (([],[5],[0,1]), [[5.0,0.0]]), true),
    ("no-constants", fn () => (([1],[],[0]), []), true),
    ("missing-constant", fn () => (([2,6],[3,~2],[0,1]), [[0.0,2.0],[0.0,2.0]]), false),
    ("wrong-division", fn () => (([2,6],[3],[2]), [[6.0]]), false),
    ("no-unspecified-tolerance", fn () => (([2,6],[3],[2]), [[3.005]]), false),
    ("wrong-rows", fn () => (([2,6],[3,~2],[0]), [[~2.0],[3.0]]), false)
  ]
end

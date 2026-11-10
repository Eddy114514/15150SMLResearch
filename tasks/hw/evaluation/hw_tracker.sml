(* Fixed functional-projection labels, not validation of the full original
 * specification. Never included in model prompts.
 * Every thunk constructs fresh values for each predicate evaluation. *)
structure Evaluation = struct
  type input = int * int list list * int * int
  type output = int list

  val requiresCases : (string * (unit -> input) * bool) list = [
    ("valid-1", fn () => (4,[[0,1],[1,2]],0,0), true),
    ("valid-2", fn () => (4,[[0,1],[1,2]],0,1), true),
    ("valid-3", fn () => (4,[[0,1],[1,2]],0,2), true),
    ("invalid-source", fn () => (0,[],0,0), false),
    ("negative-resolution", fn () => (2,[],0,~1), false),
    ("chat-duplicate", fn () => (2,[[0,0]],0,1), false),
    ("chat-out-of-range", fn () => (2,[[0,2]],0,1), false),
    ("negative-size", fn () => (~1,[],0,0), false)
  ]
  val ensuresCases : (string * (unit -> input * output) * bool) list = [
    ("literal-all-indices-at-zero-resolution", fn () => ((4,[[0,1],[1,2]],0,0), [0,1,2,3]), true),
    ("reachable-only-zero-resolution-is-insufficient", fn () => ((4,[[0,1],[1,2]],0,0), [0]), false),
    ("reachable-only-one-step-is-insufficient", fn () => ((4,[[0,1],[1,2]],0,1), [0,1]), false),
    ("reachable-only-two-steps-is-insufficient", fn () => ((4,[[0,1],[1,2]],0,2), [0,1,2]), false),
    ("order-free", fn () => ((4,[[0,1],[1,2]],0,2), [3,2,0,1]), true),
    ("missing-source", fn () => ((4,[[0,1],[1,2]],0,1), [1]), false),
    ("unreachable-mascot-is-required-by-literal-text", fn () => ((4,[[0,1],[1,2]],0,2), [0,1,2,3]), true),
    ("duplicates-and-other-integers-allowed", fn () => ((4,[[0,1],[1,2]],0,2), [0,1,2,3,3,~1,9]), true),
    ("missing-required-index", fn () => ((4,[[0,1],[1,2]],0,2), [0,2,3]), false)
  ]
end

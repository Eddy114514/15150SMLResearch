(* Fixed independent semantic labels; never included in model prompts.
 * Every thunk constructs fresh values for each predicate evaluation. *)
structure Evaluation = struct
  type input = int * int list
  type output = int list * int list

  val requiresCases : (string * (unit -> input) * bool) list = [
    ("valid-1", fn () => (2,[]), true),
    ("valid-2", fn () => (2,[3,1,2,0,1]), true)
  ]
  val ensuresCases : (string * (unit -> input * output) * bool) list = [
    ("empty", fn () => ((2,[]), ([],[])), true),
    ("partition", fn () => ((2,[3,1,2,0,1]), ([1,0,1],[3,2])), true),
    ("equal-on-wrong-side", fn () => ((2,[3,1,2,0,1]), ([1,2,0,1],[3])), false),
    ("wrong-order", fn () => ((2,[3,1,2,0,1]), ([0,1,1],[3,2])), false),
    ("lost-occurrence", fn () => ((2,[3,1,2,0,1]), ([1,0],[3,2])), false)
  ]
end

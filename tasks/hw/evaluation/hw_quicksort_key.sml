(* Fixed independent semantic labels; never included in model prompts.
 * Every thunk constructs fresh values for each predicate evaluation. *)
structure Evaluation = struct
  type input = (int * int) list
  type output = (int * int) list

  val requiresCases : (string * (unit -> input) * bool) list = [
    ("valid-1", fn () => [(2,7),(1,4),(1,3)], true),
    ("valid-2", fn () => [], true)
  ]
  val ensuresCases : (string * (unit -> input * output) * bool) list = [
    ("equal-key-order-a", fn () => ([(2,7),(1,4),(1,3)], [(1,4),(1,3),(2,7)]), true),
    ("equal-key-order-b", fn () => ([(2,7),(1,4),(1,3)], [(1,3),(1,4),(2,7)]), true),
    ("identity-preserved", fn () => ([(2,7),(1,4),(1,3)], [(1,3),(1,3),(2,7)]), false),
    ("keys-sorted", fn () => ([(2,7),(1,4),(1,3)], [(2,7),(1,3),(1,4)]), false),
    ("empty", fn () => ([], []), true)
  ]
end

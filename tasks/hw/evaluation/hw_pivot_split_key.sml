(* Fixed independent semantic labels; never included in model prompts.
 * Every thunk constructs fresh values for each predicate evaluation. *)
structure Evaluation = struct
  type input = (int * int) * (int * int) list
  type output = (int * int) list * (int * int) list

  val requiresCases : (string * (unit -> input) * bool) list = [
    ("valid-1", fn () => ((2,9),[(2,1),(1,4),(1,3),(3,7)]), true),
    ("valid-2", fn () => ((0,0),[]), true)
  ]
  val ensuresCases : (string * (unit -> input * output) * bool) list = [
    ("partition-identity", fn () => (((2,9),[(2,1),(1,4),(1,3),(3,7)]), ([(1,4),(1,3)],[(2,1),(3,7)])), true),
    ("full-identity", fn () => (((2,9),[(2,1),(1,4),(1,3),(3,7)]), ([(1,4),(1,4)],[(2,1),(3,7)])), false),
    ("stable-partition", fn () => (((2,9),[(2,1),(1,4),(1,3),(3,7)]), ([(1,3),(1,4)],[(2,1),(3,7)])), false),
    ("empty", fn () => (((0,0),[]), ([],[])), true)
  ]
end

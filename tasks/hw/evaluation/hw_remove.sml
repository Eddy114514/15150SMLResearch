(* Fixed independent semantic labels; never included in model prompts.
 * Every thunk constructs fresh values for each predicate evaluation. *)
structure Evaluation = struct
  type input = int * int list
  type output = int list

  val requiresCases : (string * (unit -> input) * bool) list = [
    ("valid-1", fn () => (1,[]), true),
    ("valid-2", fn () => (1,[1,2,1,3,2]), true),
    ("valid-3", fn () => (9,List.tabulate (25, fn i => i)), true)
  ]
  val ensuresCases : (string * (unit -> input * output) * bool) list = [
    ("empty", fn () => ((1,[]), []), true),
    ("all-occurrences-order", fn () => ((1,[1,2,1,3,2]), [2,3,2]), true),
    ("forgot-later-occurrence", fn () => ((1,[1,2,1,3,2]), [2,1,3,2]), false),
    ("wrong-order", fn () => ((1,[1,2,1,3,2]), [2,2,3]), false),
    ("lost-duplicate", fn () => ((1,[1,2,1,3,2]), [2,3]), false)
  ]
end

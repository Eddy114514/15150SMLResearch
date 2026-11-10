(* Fixed independent semantic labels; never included in model prompts.
 * Every thunk constructs fresh values for each predicate evaluation. *)
structure Evaluation = struct
  type input = int list
  type output = int list

  val requiresCases : (string * (unit -> input) * bool) list = [
    ("valid-1", fn () => [3,1,2,1], true),
    ("valid-2", fn () => [], true)
  ]
  val ensuresCases : (string * (unit -> input * output) * bool) list = [
    ("sorted-permutation", fn () => ([3,1,2,1], [1,1,2,3]), true),
    ("empty", fn () => ([], []), true),
    ("lost-duplicate", fn () => ([3,1,2,1], [1,2,3]), false),
    ("unsorted", fn () => ([3,1,2,1], [1,2,1,3]), false),
    ("extra-value", fn () => ([3,1,2,1], [1,1,2,3,4]), false)
  ]
end

(* Fixed independent semantic labels; never included in model prompts.
 * Every thunk constructs fresh values for each predicate evaluation. *)
structure Evaluation = struct
  type input = int * int list
  type output = int

  val requiresCases : (string * (unit -> input) * bool) list = [
    ("valid-1", fn () => (1,[]), true),
    ("valid-2", fn () => (1,[1,1,2,1]), true),
    ("valid-3", fn () => (1,[2,1]), true)
  ]
  val ensuresCases : (string * (unit -> input * output) * bool) list = [
    ("empty", fn () => ((1,[]), 0), true),
    ("maximal-prefix", fn () => ((1,[1,1,2,1]), 2), true),
    ("not-total-count", fn () => ((1,[1,1,2,1]), 3), false),
    ("not-short-prefix", fn () => ((1,[1,1,2,1]), 1), false),
    ("negative", fn () => ((1,[]), ~1), false),
    ("zero-prefix", fn () => ((1,[2,1]), 0), true)
  ]
end

(* Fixed independent semantic labels; never included in model prompts.
 * Every thunk constructs fresh values for each predicate evaluation. *)
structure Evaluation = struct
  type input = int * int list
  type output = int list

  val requiresCases : (string * (unit -> input) * bool) list = [
    ("valid-1", fn () => (1,[]), true),
    ("valid-2", fn () => (1,[1,1,2,1]), true),
    ("valid-3", fn () => (1,[1,1]), true),
    ("valid-4", fn () => (1,[2,1]), true)
  ]
  val ensuresCases : (string * (unit -> input * output) * bool) list = [
    ("empty", fn () => ((1,[]), []), true),
    ("remaining-suffix", fn () => ((1,[1,1,2,1]), [2,1]), true),
    ("retain-later-matches", fn () => ((1,[1,1,2,1]), [2]), false),
    ("maximal", fn () => ((1,[1,1,2,1]), [1,2,1]), false),
    ("all-matches", fn () => ((1,[1,1]), []), true),
    ("no-prefix", fn () => ((1,[2,1]), [2,1]), true)
  ]
end

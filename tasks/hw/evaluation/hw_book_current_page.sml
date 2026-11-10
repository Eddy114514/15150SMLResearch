(* Fixed independent semantic labels; never included in model prompts.
 * Every thunk constructs fresh values for each predicate evaluation. *)
structure Evaluation = struct
  type input = string list * int
  type output = BookCase.view

  val requiresCases : (string * (unit -> input) * bool) list = [
    ("valid-1", fn () => ([],0), true),
    ("valid-2", fn () => (["a","b"],0), true),
    ("valid-3", fn () => (["a","b"],1), true),
    ("valid-4", fn () => (["a","b"],2), true),
    ("negative-cursor", fn () => (["a"],~1), false),
    ("beyond-end", fn () => (["a"],2), false)
  ]
  val ensuresCases : (string * (unit -> input * output) * bool) list = [
    ("empty-start-end", fn () => (([],0), (true,NONE)), true),
    ("first-page", fn () => ((["a","b"],0), (true,SOME "a")), true),
    ("second-page", fn () => ((["a","b"],1), (false,SOME "b")), true),
    ("past-last", fn () => ((["a","b"],2), (false,NONE)), true),
    ("wrong-start-flag", fn () => ((["a","b"],1), (true,SOME "b")), false),
    ("wrong-page", fn () => ((["a","b"],1), (false,SOME "a")), false),
    ("false-end", fn () => ((["a","b"],1), (false,NONE)), false)
  ]
end

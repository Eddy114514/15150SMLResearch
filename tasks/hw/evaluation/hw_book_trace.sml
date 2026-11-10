(* Fixed independent semantic labels; never included in model prompts.
 * Every thunk constructs fresh values for each predicate evaluation. *)
structure Evaluation = struct
  type input = string list * BookCase.direction list
  type output = BookCase.snapshot * BookCase.observedStep list

  val requiresCases : (string * (unit -> input) * bool) list = [
    ("valid-1", fn () => ([],[]), true),
    ("valid-2", fn () => (["a"],[BookCase.Forward,BookCase.Backward]), true),
    ("valid-3", fn () => (["a"],[BookCase.Backward,BookCase.Forward]), true),
    ("valid-4", fn () => (["a"],[BookCase.Forward]), true)
  ]
  val ensuresCases : (string * (unit -> input * output) * bool) list = [
    ("empty-no-steps", fn () => (([],[]), (([],(true,NONE)),[])), true),
    ("round-trip", fn () => ((["a"],[BookCase.Forward,BookCase.Backward]), ((["a"],(true,SOME "a")),[(BookCase.Moved (false,NONE),["a"]),(BookCase.Moved (true,SOME "a"),["a"])])), true),
    ("boundary-retains-state", fn () => ((["a"],[BookCase.Backward,BookCase.Forward]), ((["a"],(true,SOME "a")),[(BookCase.OutOfBounds (true,SOME "a"),["a"]),(BookCase.Moved (false,NONE),["a"])])), true),
    ("refuses-valid-forward", fn () => ((["a"],[BookCase.Backward,BookCase.Forward]), ((["a"],(true,SOME "a")),[(BookCase.OutOfBounds (true,SOME "a"),["a"]),(BookCase.OutOfBounds (true,SOME "a"),["a"])])), false),
    ("lost-end-content", fn () => ((["a"],[BookCase.Forward]), ((["a"],(true,SOME "a")),[(BookCase.Moved (false,NONE),[])])), false)
  ]
end

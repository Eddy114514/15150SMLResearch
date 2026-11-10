(* Fixed independent semantic labels; never included in model prompts.
 * Every thunk constructs fresh values for each predicate evaluation. *)
structure Evaluation = struct
  type input = string list * int * BookCase.direction
  type output = BookCase.observedStep

  val requiresCases : (string * (unit -> input) * bool) list = [
    ("valid-1", fn () => (["a","b"],0,BookCase.Forward), true),
    ("valid-2", fn () => (["a"],0,BookCase.Forward), true),
    ("valid-3", fn () => (["a"],1,BookCase.Backward), true),
    ("valid-4", fn () => (["a"],0,BookCase.Backward), true),
    ("negative-cursor", fn () => (["a"],~1,BookCase.Forward), false),
    ("beyond-end", fn () => (["a"],2,BookCase.Backward), false)
  ]
  val ensuresCases : (string * (unit -> input * output) * bool) list = [
    ("forward", fn () => ((["a","b"],0,BookCase.Forward), (BookCase.Moved (false,SOME "b"),["a","b"])), true),
    ("to-end-keeps-contents", fn () => ((["a"],0,BookCase.Forward), (BookCase.Moved (false,NONE),["a"])), true),
    ("back-from-end", fn () => ((["a"],1,BookCase.Backward), (BookCase.Moved (true,SOME "a"),["a"])), true),
    ("prescribed-boundary", fn () => ((["a"],0,BookCase.Backward), (BookCase.OutOfBounds (true,SOME "a"),["a"])), true),
    ("wrong-outcome-tag", fn () => ((["a"],0,BookCase.Backward), (BookCase.Moved (true,SOME "a"),["a"])), false),
    ("lost-content-at-end", fn () => ((["a"],0,BookCase.Forward), (BookCase.Moved (false,NONE),[])), false)
  ]
end

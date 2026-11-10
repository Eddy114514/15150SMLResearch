(* Fixed independent semantic labels; never included in model prompts.
 * Every thunk constructs fresh values for each predicate evaluation. *)
structure Evaluation = struct
  type input = string list
  type output = BookCase.snapshot * BookCase.step list

  val requiresCases : (string * (unit -> input) * bool) list = [
    ("valid-1", fn () => [], true),
    ("valid-2", fn () => ["a","b"], true)
  ]
  val ensuresCases : (string * (unit -> input * output) * bool) list = [
    ("empty", fn () => ([], (([],(true,NONE)),[])), true),
    ("walk-through-end", fn () => (["a","b"], ((["a","b"],(true,SOME "a")),[BookCase.Moved (false,SOME "b"),BookCase.Moved (false,NONE)])), true),
    ("additional-pages-allowed", fn () => (["a","b"], ((["extra","a","b"],(false,SOME "a")),[BookCase.Moved (false,SOME "b"),BookCase.Moved (false,NONE)])), true),
    ("empty-input-can-encode-extra-pages", fn () => ([], ((["extra"],(true,SOME "extra")),[])), true),
    ("wrong-initial-page", fn () => (["a","b"], ((["a","b"],(true,SOME "b")),[BookCase.Moved (false,SOME "b"),BookCase.Moved (false,NONE)])), false),
    ("later-flip-is-not-bind-contract", fn () => (["a","b"], ((["a","b"],(true,SOME "a")),[BookCase.Moved (false,SOME "b"),BookCase.OutOfBounds (false,SOME "b")])), true),
    ("order-matters", fn () => (["a","b"], ((["b","a"],(true,SOME "b")),[BookCase.Moved (false,SOME "a"),BookCase.Moved (false,NONE)])), false),
    ("lost-content", fn () => (["a","b"], ((["a"],(true,SOME "a")),[BookCase.Moved (false,SOME "b"),BookCase.Moved (false,NONE)])), false)
  ]
end

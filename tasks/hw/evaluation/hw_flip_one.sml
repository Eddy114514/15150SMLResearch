(* Fixed independent semantic labels; never included in model prompts.
 * Every thunk constructs fresh values for each predicate evaluation. *)
structure Evaluation = struct
  type input = bool list
  type output = bool list list

  val requiresCases : (string * (unit -> input) * bool) list = [
    ("valid-1", fn () => [], true),
    ("valid-2", fn () => [false,false], true),
    ("valid-3", fn () => [true,false,true], true),
    ("valid-4", fn () => [true,false], true)
  ]
  val ensuresCases : (string * (unit -> input * output) * bool) list = [
    ("empty", fn () => ([], []), true),
    ("no-true", fn () => ([false,false], []), true),
    ("all-positions", fn () => ([true,false,true], [[false,false,true],[true,false,false]]), true),
    ("any-result-order", fn () => ([true,false,true], [[true,false,false],[false,false,true]]), true),
    ("repeated-legal-way-is-allowed", fn () => ([true,false,true], [[false,false,true],[true,false,false],[false,false,true]]), true),
    ("missing-position", fn () => ([true,false,true], [[false,false,true]]), false),
    ("repetition-does-not-cover-missing-position", fn () => ([true,false,true], [[false,false,true],[false,false,true]]), false),
    ("two-flips", fn () => ([true,false,true], [[false,false,false],[true,false,false]]), false),
    ("false-to-true", fn () => ([true,false], [[false,false],[true,true]]), false)
  ]
end

(* Fixed functional-projection labels, not validation of the full original
 * specification. Never included in model prompts.
 * Every thunk constructs fresh values for each predicate evaluation. *)
structure Evaluation = struct
  type input = int Seq.t
  type output = int Seq.t

  val requiresCases : (string * (unit -> input) * bool) list = [
    ("valid-1", fn () => Seq.fromList [2,1,2,3], true),
    ("valid-2", fn () => Seq.fromList [], true)
  ]
  val ensuresCases : (string * (unit -> input * output) * bool) list = [
    ("deduplicate", fn () => (Seq.fromList [2,1,2,3], Seq.fromList [1,2,3]), true),
    ("empty", fn () => (Seq.fromList [], Seq.fromList []), true),
    ("duplicate", fn () => (Seq.fromList [2,1,2,3], Seq.fromList [1,2,2,3]), false),
    ("missing-class", fn () => (Seq.fromList [2,1,2,3], Seq.fromList [1,3]), false),
    ("extra-class-is-allowed", fn () => (Seq.fromList [2,1,2,3], Seq.fromList [1,2,3,4]), true),
    ("empty-input-allows-increasing-output", fn () => (Seq.fromList [], Seq.fromList [~2,7]), true),
    ("order", fn () => (Seq.fromList [2,1,2,3], Seq.fromList [2,1,3]), false)
  ]
end

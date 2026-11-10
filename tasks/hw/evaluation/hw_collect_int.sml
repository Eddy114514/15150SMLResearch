(* Fixed functional-projection labels, not validation of the full original
 * specification. Never included in model prompts.
 * Every thunk constructs fresh values for each predicate evaluation. *)
structure Evaluation = struct
  type input = int Seq.t
  type output = int Seq.t Seq.t
  fun groups rows = Seq.fromList (List.map Seq.fromList rows)

  val requiresCases : (string * (unit -> input) * bool) list = [
    ("valid-1", fn () => Seq.fromList [2,1,2,3], true),
    ("valid-2", fn () => Seq.fromList [], true)
  ]
  val ensuresCases : (string * (unit -> input * output) * bool) list = [
    ("groups", fn () => (Seq.fromList [2,1,2,3], groups [[1],[2,2],[3]]), true),
    ("weak-occurrence-counts", fn () => (Seq.fromList [2,1,2,3], groups [[1,1],[2],[3]]), true),
    ("extra-value-within-total-length", fn () => (Seq.fromList [1,1,2], groups [[1],[2],[3]]), true),
    ("empty", fn () => (Seq.fromList [], groups []), true),
    ("wrong-total-length", fn () => (Seq.fromList [2,1,2,3], groups [[1],[2],[3]]), false),
    ("empty-group", fn () => (Seq.fromList [2,1,2,3], groups [[1],[],[2,2],[3]]), false),
    ("nonhomogeneous", fn () => (Seq.fromList [2,1,2,3], groups [[1,2],[2],[3]]), false),
    ("group-order", fn () => (Seq.fromList [2,1,2,3], groups [[2,2],[1],[3]]), false)
  ]
end

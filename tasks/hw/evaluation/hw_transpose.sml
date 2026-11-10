(* Fixed functional-projection labels, not validation of the full original
 * specification. Never included in model prompts.
 * Every thunk constructs fresh values for each predicate evaluation. *)
structure Evaluation = struct
  type input = int Seq.t Seq.t
  type output = int Seq.t Seq.t
  fun matrix rows = Seq.fromList (List.map Seq.fromList rows)

  val requiresCases : (string * (unit -> input) * bool) list = [
    ("valid-1", fn () => matrix [[1,2,3],[4,5,6]], true),
    ("valid-2", fn () => matrix [], true),
    ("valid-3", fn () => matrix [[],[]], true),
    ("ragged", fn () => matrix [[1],[2,3]], false),
    ("empty-first-ragged", fn () => matrix [[],[1]], false)
  ]
  val ensuresCases : (string * (unit -> input * output) * bool) list = [
    ("rectangular", fn () => (matrix [[1,2,3],[4,5,6]], matrix [[1,4],[2,5],[3,6]]), true),
    ("empty", fn () => (matrix [], matrix []), true),
    ("zero-columns", fn () => (matrix [[],[]], matrix []), true),
    ("dimensions", fn () => (matrix [[1,2,3],[4,5,6]], matrix [[1,4],[2,5]]), false),
    ("cell-order", fn () => (matrix [[1,2,3],[4,5,6]], matrix [[1,4],[5,2],[3,6]]), false),
    ("zero-cols-result", fn () => (matrix [[],[]], matrix [[],[]]), false)
  ]
end

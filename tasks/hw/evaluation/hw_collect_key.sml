(* Fixed functional-projection labels, not validation of the full original
 * specification. Never included in model prompts.
 * Every thunk constructs fresh values for each predicate evaluation. *)
structure Evaluation = struct
  type input = (int * int) Seq.t
  type output = (int * int) Seq.t Seq.t
  fun groups rows = Seq.fromList (List.map Seq.fromList rows)

  val requiresCases : (string * (unit -> input) * bool) list = [
    ("valid-1", fn () => Seq.fromList [(2,8),(1,4),(1,3)], true),
    ("valid-2", fn () => Seq.fromList [], true)
  ]
  val ensuresCases : (string * (unit -> input * output) * bool) list = [
    ("member-order-a", fn () => (Seq.fromList [(2,8),(1,4),(1,3)], groups [[(1,4),(1,3)],[(2,8)]]), true),
    ("member-order-b", fn () => (Seq.fromList [(2,8),(1,4),(1,3)], groups [[(1,3),(1,4)],[(2,8)]]), true),
    ("extra-pair-within-total-length", fn () => (Seq.fromList [(1,4),(1,4),(2,8)], groups [[(1,4)],[(2,8)],[(3,9)]]), true),
    ("changed-occurrence-counts", fn () => (Seq.fromList [(1,4),(1,4),(2,8)], groups [[(1,4)],[(2,8),(2,8)]]), true),
    ("identity-duplication", fn () => (Seq.fromList [(2,8),(1,4),(1,3)], groups [[(1,4),(1,4)],[(2,8)]]), false),
    ("split-equivalence-class", fn () => (Seq.fromList [(2,8),(1,4),(1,3)], groups [[(1,4)],[(1,3)],[(2,8)]]), false),
    ("group-order", fn () => (Seq.fromList [(2,8),(1,4),(1,3)], groups [[(2,8)],[(1,3),(1,4)]]), false),
    ("empty", fn () => (Seq.fromList [], groups []), true)
  ]
end

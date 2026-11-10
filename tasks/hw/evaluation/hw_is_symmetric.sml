(* Fixed independent semantic labels; never included in model prompts.
 * Every thunk constructs fresh values for each predicate evaluation. *)
structure Evaluation = struct
  type input = SymmetryInput.tree
  type output = bool

  val requiresCases : (string * (unit -> input) * bool) list = [
    ("valid-1", fn () => SymmetryInput.Empty, true),
    ("valid-2", fn () => SymmetryInput.Node (SymmetryInput.Node (SymmetryInput.Empty,1,SymmetryInput.Empty),0,SymmetryInput.Node (SymmetryInput.Empty,9,SymmetryInput.Empty)), true),
    ("valid-3", fn () => SymmetryInput.Node (SymmetryInput.Empty,0,SymmetryInput.Node (SymmetryInput.Empty,9,SymmetryInput.Empty)), true)
  ]
  val ensuresCases : (string * (unit -> input * output) * bool) list = [
    ("empty", fn () => (SymmetryInput.Empty, true), true),
    ("shape-ignores-values", fn () => (SymmetryInput.Node (SymmetryInput.Node (SymmetryInput.Empty,1,SymmetryInput.Empty),0,SymmetryInput.Node (SymmetryInput.Empty,9,SymmetryInput.Empty)), true), true),
    ("asymmetric", fn () => (SymmetryInput.Node (SymmetryInput.Empty,0,SymmetryInput.Node (SymmetryInput.Empty,9,SymmetryInput.Empty)), false), true),
    ("wrong-empty", fn () => (SymmetryInput.Empty, false), false),
    ("wrong-shape", fn () => (SymmetryInput.Node (SymmetryInput.Empty,0,SymmetryInput.Node (SymmetryInput.Empty,9,SymmetryInput.Empty)), true), false)
  ]
end

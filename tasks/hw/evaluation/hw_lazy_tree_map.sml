(* Fixed independent semantic labels; never included in model prompts.
 * Every thunk constructs fresh values for each predicate evaluation. *)
structure Evaluation = struct
  type input = Affine.t * SymmetryInput.tree
  type output = int * int * SymmetryInput.tree

  val requiresCases : (string * (unit -> input) * bool) list = [
    ("valid-1", fn () => ((2,1),SymmetryInput.Empty), true),
    ("valid-2", fn () => ((2,1),SymmetryInput.Node (SymmetryInput.Empty,3,SymmetryInput.Empty)), true)
  ]
  val ensuresCases : (string * (unit -> input * output) * bool) list = [
    ("empty", fn () => (((2,1),SymmetryInput.Empty), (0,0,SymmetryInput.Empty)), true),
    ("mapped-value", fn () => (((2,1),SymmetryInput.Node (SymmetryInput.Empty,3,SymmetryInput.Empty)), (0,0,SymmetryInput.Node (SymmetryInput.Empty,7,SymmetryInput.Empty))), true),
    ("wrong-value", fn () => (((2,1),SymmetryInput.Node (SymmetryInput.Empty,3,SymmetryInput.Empty)), (0,0,SymmetryInput.Node (SymmetryInput.Empty,6,SymmetryInput.Empty))), false),
    ("lost-shape", fn () => (((2,1),SymmetryInput.Node (SymmetryInput.Empty,3,SymmetryInput.Empty)), (0,0,SymmetryInput.Empty)), false),
    ("early-tree-force", fn () => (((2,1),SymmetryInput.Node (SymmetryInput.Empty,3,SymmetryInput.Empty)), (1,0,SymmetryInput.Node (SymmetryInput.Empty,7,SymmetryInput.Empty))), false),
    ("early-mapper-call", fn () => (((2,1),SymmetryInput.Node (SymmetryInput.Empty,3,SymmetryInput.Empty)), (1,1,SymmetryInput.Node (SymmetryInput.Empty,7,SymmetryInput.Empty))), false)
  ]
end

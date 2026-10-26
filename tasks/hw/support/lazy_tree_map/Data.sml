(* Finite trees have at most 15 nodes. Values and affine parameters are -3..3.
 * These are generation settings; the original map precondition is true. *)
structure LazyTreeMapData = struct
  structure G = QCheck.Gen
  open SymmetryInput
  val value = G.range (~3,3)
  val tree = IntegerTreeData.tree value
  val genInput = G.zip (G.zip(value,value),tree 15)
  val leaf = fn x => Node(Empty,x,Empty)
  val edges = [((1,0),Empty),((1,0),leaf 0),((~2,3),leaf (~3)),
    ((2,1),Node(leaf 2,0,leaf 2)),
    ((1,~1),Node(Node(leaf (~1),0,Empty),1,Empty)),
    ((0,~1),Node(Empty,3,leaf (~3)))]

  fun showInput ((a,b),t) = Runner.object
    [("mapper",Runner.object [("a",Runner.int a),("b",Runner.int b)]),
     ("tree",IntegerTreeData.show t)]
  fun showOutput (treeForces,mapperCalls,t) = Runner.object
    [("construction_tree_forces",Runner.int treeForces),
     ("construction_mapper_calls",Runner.int mapperCalls),("tree",IntegerTreeData.show t)]
end

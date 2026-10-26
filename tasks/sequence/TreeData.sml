(* This runnable non-Sequence example samples leaves and depth-one nodes.
 * A fixed depth-two edge exercises nested input display. It does not claim to
 * execute the depth-three Sequence-of-tree example in Data.sml. *)
local
  structure G = QCheck.Gen
  val leafGen = G.map Tree.Leaf Generators.intGen
in
  structure TreeLeafData = struct
    val genInput : Tree.tree G.gen =
      G.choose #[leafGen, G.map Tree.Node (G.zip (leafGen, leafGen))]
    val edges = [Tree.Leaf 0, Tree.Node (Tree.Leaf 0, Tree.Leaf 1),
                 Tree.Leaf (valOf Int.minInt), Tree.Leaf (valOf Int.maxInt),
                 Tree.Node (Tree.Node (Tree.Leaf ~1, Tree.Leaf 2), Tree.Leaf 0)]
    val showInput = TreeDisplay.show
    val showOutput = Runner.bool
  end
end

(* This runnable non-Sequence example samples leaves and depth-one nodes.
 * A fixed depth-two edge exercises nested input display. It does not claim to
 * execute the depth-three Sequence-of-tree example in Data.sml. *)
structure TreeLeafData = struct
  val genInput = TreeSupport.gen Generators.intGen 1
  val edges = [Tree.Leaf 0, Tree.Node (Tree.Leaf 0, Tree.Leaf 1),
               Tree.Leaf (valOf Int.minInt), Tree.Leaf (valOf Int.maxInt),
               Tree.Node (Tree.Node (Tree.Leaf ~1, Tree.Leaf 2), Tree.Leaf 0)]
  val showInput = TreeSupport.show
  val showOutput = Runner.bool
end

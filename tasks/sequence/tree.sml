(* @contract treeIsLeaf
 * treeIsLeaf : Tree.tree -> bool
 * REQUIRES: true
 * ENSURES: The result is true if and only if the outermost constructor of tree
 *          is Tree.Leaf. For Tree.Node the result is false, regardless of all
 *          descendant constructors and integer labels.
 *)
fun treeIsLeaf (Tree.Leaf _) = true
  | treeIsLeaf (Tree.Node _) = false

(* @solution *)
(* @contract treeIsLeaf
 * treeIsLeaf : Tree.tree -> bool
 * REQUIRES: true
 * ENSURES: The result is true if and only if the outermost constructor of tree
 *          is Tree.Leaf. For Tree.Node the result is false, regardless of all
 *          descendant constructors and integer labels.
 *)
fun treeIsLeaf (Tree.Leaf _) = true
  | treeIsLeaf (Tree.Node _) = false
(* @manual tree_is_leaf *)
(* @contract treeIsLeaf
 * treeIsLeaf : Tree.tree -> bool
 * REQUIRES: true
 * ENSURES: The result is true if and only if the outermost constructor of tree
 *          is Tree.Leaf. For Tree.Node the result is false, regardless of all
 *          descendant constructors and integer labels.
 *)
functor ManualContract (Helpers : sig
end) = struct
  type input = Tree.tree
  type output = bool
  fun requires (input : input) : bool = let val tree = input in (true) end
  fun ensures (input : input) (result : output) : bool = let val tree = input in (result = (case tree of Tree.Leaf _ => true | Tree.Node _ => false)) end
end

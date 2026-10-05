(* Original solution: 15150HW/HWANS/228020278/code/tree-rev/isSymmetric.sml. *)
(* @solution *)
datatype tree = Empty | Node of tree * int * tree

(* isSymmetric : tree -> bool
 * REQUIRES: true
 * ENSURES: isSymmetric T ==>* true iff T is symmetric w.r.t the root
 *)
fun helpSym(Empty, Empty) = true
  | helpSym(Node(ll,x,lr), Node(rl,y,rr)) = helpSym(ll,rr) andalso helpSym(lr,rl)  
  | helpSym(_,_) = false

fun isSymmetric (Empty : tree) : bool = true
  | isSymmetric (Node(l, x, r)) = helpSym(l,r)

(*
val true = isSymmetric(Node(Empty,1,Empty))
val false = isSymmetric(Node(Node(Node(Empty,1,Empty),2,Empty),1,Node(Empty,3,Empty)))
val true = isSymmetric(Node(Node(Node(Empty,1,Empty),2,Empty),1,Node(Empty,3,Node(Empty,4,Empty))))
val false = isSymmetric(Node(Node(Node(Empty,1,Empty),2,Empty),1,Node(Node(Empty,3,Empty),3,Node(Empty,4,Empty))))
val true = isSymmetric(Node(Node(Empty,2,Node(Empty,4,Empty)),1,Node(Node(Empty,3,Empty),3,Empty)))
val true = isSymmetric(Node(Node(Node(Empty,4,Node(Node(Empty,3,Empty),3,Empty)),2,Node(Empty,5,Node(Empty,7,Empty))),1,Node(Node(Node(Empty,8,Empty),6,Empty),3,Node(Node(Empty,3,Node(Empty,3,Empty)),7,Empty))))
*)
(* @manual hw_is_symmetric *)
(* @contract isSymmetric
 * isSymmetric : tree -> bool
 * REQUIRES: true
 * ENSURES: True iff the tree's shape is invariant under reflection.
 * HWANS examples explicitly accept mirror positions with unequal values.
 * Values are retained by the adapter, but are not part of this symmetry rule.
 *)
functor ManualContract (Helpers : sig end) = struct
  type input = SymmetryInput.tree
  type output = bool
  datatype shape = Tip | Fork of shape * shape
  fun view reflected SymmetryInput.Empty = Tip
    | view reflected (SymmetryInput.Node(l,_,r)) =
        if reflected then Fork(view reflected r, view reflected l)
        else Fork(view reflected l, view reflected r)
  fun requires (_ : input) = true
  fun ensures tree result = (result = (view false tree = view true tree))
end

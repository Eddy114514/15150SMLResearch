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
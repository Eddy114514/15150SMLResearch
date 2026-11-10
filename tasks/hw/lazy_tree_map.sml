(* @solution *)
structure LazyTree : LAZYTREE =
struct
  datatype 'a lazyTree  = LT of unit -> 'a treeFront
  and      'a treeFront = LEAF | NODE of 'a lazyTree * 'a * 'a lazyTree

  val delay = LT
  fun expose (LT t) = t ()

  (* map: ('a -> 'b) -> 'a lazyTree -> 'b lazyTree
   * REQUIRES: true
   * ENSURES: map f t = t' where
   *     - t' has the same shape as t
   *     - Each x in t is replaced with f x in t'
   *     - map f t is maximally lazy (Evaluating map f t never calls f or exposes
   *       any elements of the tree)
   *)
  fun map f t = delay(fn () => map' f (expose t))
  and map' f LEAF = LEAF
    | map' f (NODE(l, x, r)) = NODE(map f l, f x, map f r)

  (* preOrd: 'a lazyTree -> 'a Stream.t
   * REQUIRES: true
   * ENSURES: preOrd t = l where
   *     - l is the pre-order traversal for t (the pre-order traversal is the current
   *       node, then the left subtree, then the right subtree)
   *     - preOrd t is maximally lazy (Evaluating preOrd t does not expose any
   *       elements of the tree)
   *)
  fun preOrd t = Stream.delay(fn () => preOrd' (expose t))
  and preOrd' LEAF = Stream.Empty
    | preOrd' (NODE(l, x, r)) = Stream.Cons(x, 
        Stream.append(preOrd l, preOrd r)
        )
    
end

(* @manual hw_lazy_tree_map *)
(* @contract lazy_tree_map
 * LazyTree.map : ('a -> 'b) -> 'a LazyTree.lazyTree -> 'b LazyTree.lazyTree
 * REQUIRES: true in the original problem. This instance constructs finite
 * int trees and affine int -> int functions from printable descriptions.
 * ENSURES: The output has the same shape and each value is transformed by f.
 * Constructing the result neither exposes the input tree nor calls f.
 * The finite instance is fully observed. The original parenthesis defines
 * maximal laziness at construction, exactly when these counters are captured.
 * No requirement about later demand traces is added.
 * Sampling bounds control test cost and arithmetic; they are not preconditions.
 *)
functor ManualContract (Helpers : sig end) = struct
  type input = Affine.t * SymmetryInput.tree
  type output = int * int * SymmetryInput.tree
  fun requires (_ : input) = true

  fun matches (a,b) (SymmetryInput.Empty,SymmetryInput.Empty) = true
    | matches (a,b) (SymmetryInput.Node(l,x,r),SymmetryInput.Node(l',y,r')) =
        IntInf.fromInt y = IntInf.fromInt a * IntInf.fromInt x + IntInf.fromInt b
        andalso matches (a,b) (l,l') andalso matches (a,b) (r,r')
    | matches _ _ = false

  fun ensures (mapper,tree) (treeForces,mapperCalls,result) =
    treeForces = 0 andalso mapperCalls = 0 andalso matches mapper (tree,result)
end

(* defining type 'a ord *)
type 'a ord = 'a * 'a -> order

fun compareOrder (x : order, y : order) : bool =
    (case (x,y) of
         (GREATER,GREATER) => true
       | (EQUAL,EQUAL) => true
       | (LESS,LESS) => true
       | _ => false)

fun compareLists (cmp : 'a ord, L1 : 'a list, L2 : 'a list) : bool =
    (case (L1, L2) of
         ([], []) => true
       | (_, []) => false
       | ([], _) => false
       | (x::xs, y::ys) => compareOrder (cmp (x, y), EQUAL) andalso compareLists (cmp, xs, ys))

(* Use this function to test your implementation of pivotSplit
 * with the corresponding comparison function *)
fun compareListsPairs (cmp, (L1, L2), (R1, R2)) =
    compareLists (cmp, L1, R1) andalso compareLists (cmp, L2, R2)

(* Use this function to test your implementation of quicksort
 * with the corresponding comparison function *)
fun isSorted (cmp : 'a ord, L : 'a list) : bool =
    (case L of
          [] => true
     | x::[] => true
     | x::y::xs => not (compareOrder (cmp (x,y),GREATER))
                   andalso isSorted (cmp, y::xs))

(* pivotSplit : 'a ord * 'a * 'a list -> 'a list * 'a list
 * REQUIRES: cmp is an order function
 * ENSURES: pivotSplit (cmp,p,L) returns (A,B) such that A @ B is a
 *   permutation of L, where all elements in A are less than p, and all elements
 *   in B are greater than or equal to p. Also, for elements x, y : 'a and
 *   for L : 'a list, if x occurs earlier than y and both x and y are in the
 *   same partition, then x occurs earlier than y in the partition. *)
fun pivotSplit (cmp : 'a ord, p : 'a, [] : 'a list) : 'a list * 'a list = ([],[])
  | pivotSplit (cmp : 'a ord, p : 'a, x::xs  : 'a list) : 'a list * 'a list = 
    let
      val (A,B) = pivotSplit(cmp, p, xs)
    in
      case cmp(x,p) of 
        LESS => (x::A, B)
      | GREATER => (A,x::B)
      | EQUAL => (A,x:: B)
    end

(* Uncomment to test!
val get1 = pivotSplit ( Int.compare , 0 , [4 ,~2 ,6 ,4 ,~3 ,2 ,6 ,7]);
val get2 = pivotSplit ( Int.compare , 4 , [4 ,~2 ,6 ,4 ,~3 ,2 ,6 ,7])
val get3 = pivotSplit ( String.compare , " extensional ",
[" qwerty ", "fun", " doop ", "wow", " cool "]);
*)

(* quicksort : 'a ord * 'a list -> 'a list
 * REQUIRES: cmp is an order function
 * ENSURES: quicksort (cmp,L) evaluates to a cmp-sorted permutation of L
 *)
fun quicksort (cmp : 'a ord, [] : 'a list) : 'a list = []
  | quicksort (cmp : 'a ord, x::xs : 'a list) : 'a list = 
  let
    val (A,B) = pivotSplit(cmp, x, xs)
  in
    quicksort(cmp, A) @ x::quicksort(cmp, B)
  end

(* Uncomment to test!
val check1 = isSorted(Int.compare,quicksort(Int.compare, [4 ,~2 ,6 ,4 ,~3 ,2 ,6 ,7]))
val check2 = isSorted(Int.compare,quicksort(Int.compare, [1 ,~2 ,1 ,4 ,~5 ,1 ,4 ,1, 9, 1, 9]))
val check3 = isSorted(String.compare,quicksort(String.compare, [" qwerty ", "fun", " doop ", "wow", " cool "]))
*)
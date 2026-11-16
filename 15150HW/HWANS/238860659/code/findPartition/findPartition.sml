(* findPartitionV1 :
 *  'e list ->
 *  ('e list -> 'l option) ->
 *  ('e list -> 'r option) ->
 *  ('l * 'r) option
 * REQUIRES: pL and pR are total
 * ENSURES: findPartitionV1 A pL pR ==>*
 *  SOME (evL, evR) if there exists a partition (L, R) of A
 *  such that pL accepts L with evL and pR accepts R with evR.
 *  NONE otherwise.
 *)
fun findPartitionV1
  (A : 'e list)
  (pL : 'e list -> 'l option)
  (pR : 'e list -> 'r option)
  : ('l * 'r) option =
  let
    fun help ([],L,R) = 
      (case (pL(L),pR(R)) of 
        (SOME evL, SOME evR) => SOME (evL, evR)
       | _ => NONE)
      | help (x::xs, L, R) = 
      (case help(xs, L@[x], R) of
             SOME result => SOME result
           | NONE => help(xs, L, R@[x]))
  in
    help(A, [], [])
  end

(*
val sum : int list -> int = foldr op+ 0
fun subsetSumV1 ( n : int) ( xs : int list ) : int list option =
let
val pL = fn L => if sum L = n then SOME L else NONE
val pR = fn R => SOME R
val res = findPartitionV1 xs pL pR
fun extractL ( SOME ( partL , partR ) ) = SOME partL
| extractL NONE = NONE
in
extractL res
end

val () = Test.int_list_option ("Test 1", SOME [], subsetSumV1 0 []) 
val () = Test.int_list_option ("Test 2", NONE, subsetSumV1 1 [])
val () = Test.int_list_option ("Test 3", SOME [1], subsetSumV1 1 [1]) 
val () = Test.int_list_option ("Test 4", SOME [1,1], subsetSumV1 2 [1,1]) 
val () = Test.int_list_option ("Test 5", SOME [1,2], subsetSumV1 3 [1,2,1]) 
val () = Test.int_list_option ("Test 6", SOME [2,1], subsetSumV1 3 [5,2,1]) 

*)
(* findPartitionV2 :
 *  'e list ->
 *  ('e list -> 'l option) ->
 *  ('e list -> 'r option) ->
 *  ('l * 'r -> 'a) ->
 *  (unit -> 'a) ->
 *  'a
 * REQUIRES: pL and pR are total
 * ENSURES: findPartitionV2 A pL pR sc fc ==>*
 *  sc (evL, evR) if there exists a partition (L, R) of A
 *  such that pL accepts L with evL and pR accepts R with evR.
 *  fc () otherwise.
 *)
fun findPartitionV2
  ([] : 'e list)
  (pL : 'e list -> 'l option)
  (pR : 'e list -> 'r option)
  (sc : 'l * 'r -> 'a)
  (fc : unit -> 'a)
  : 'a = 
  (case (pL([]),pR([])) of 
    (SOME evL, SOME evR) => sc (evL, evR)
  | _ => fc ())
  | findPartitionV2 (x::xs) pL pR sc fc = 
    let 
      val newPL = fn list => pL(x::list)
      val newPR = fn list => pR(x::list)
      val newFC = fn () => findPartitionV2 xs pL newPR sc fc
    in 
      findPartitionV2 xs newPL pR sc newFC
    end

(*
val sum : int list -> int = foldr op+ 0
fun subsetSum ( n : int) ( xs : int list ) : int list option =
let
val pL = fn L => if sum L = n then SOME L else NONE
val pR = fn R => SOME R
val sc = fn (l , r ) => SOME l
val fc = fn () => NONE
in
findPartitionV2 xs pL pR sc fc
end

val () = Test.int_list_option ("Test 1", SOME [], subsetSum 0 []) 
val () = Test.int_list_option ("Test 2", NONE, subsetSum 1 [])
val () = Test.int_list_option ("Test 3", SOME [1], subsetSum 1 [1]) 
val () = Test.int_list_option ("Test 4", SOME [1,1], subsetSum 2 [1,1]) 
val () = Test.int_list_option ("Test 5", SOME [1,2], subsetSum 3 [1,2,1]) 
val () = Test.int_list_option ("Test 6", SOME [2,1], subsetSum 3 [5,2,1]) 
*)

(* findPartition :
 *  'e list ->
 *  ('e list -> ('l -> 'a) -> (unit -> 'a) -> 'a) ->
 *  ('e list -> ('r -> 'a) -> (unit -> 'a) -> 'a) ->
 *  ('l * 'r -> 'a) ->
 *  (unit -> 'a) ->
 *  'a
 * REQUIRES: pL and pR are CPS-total
 * ENSURES: findPartition A pL pR sc fc ==>
 *  sc (evL, evR) if there exists a partition (L, R) of A
 *  such that pL accepts L with evL and pR accepts R with evR.
 *  fc () otherwise.
 *)
fun findPartition
  ([] : 'e list)
  (pL : 'e list -> ('l -> 'a) -> (unit -> 'a) -> 'a)
  (pR : 'e list -> ('r -> 'a) -> (unit -> 'a) -> 'a)
  (sc : 'l * 'r -> 'a)
  (fc : unit -> 'a)
  : 'a = 
  pL [] (fn L => pR [] (fn R => sc (L, R))(fn () => fc ())) fc
  | findPartition (x::xs) pL pR sc fc = 
    let
      val newFC = fn () => findPartition xs pL (fn list => pR (x::list)) sc fc
    in
      findPartition xs (fn list => pL (x::list)) pR sc newFC
    end


(*
val sum : int list -> int = foldr op+ 0

fun subsetSum ( n : int) ( xs : int list ) =
let
fun pL L scL fcL = if foldl (fn (x, acc) => acc andalso (x < 5)) true L then scL L else fcL ()
fun pR R scR fcR = if foldl (fn (x, acc) => acc andalso (x > 5)) true R then scR R else fcR ()
fun sc (LJ,RJ) = SOME (LJ,RJ)
fun fc () = NONE
in
findPartition xs pL pR sc fc
end



val get = subsetSum 5 [1,2,3,4,6,7,8,9,10]
val get1 = subsetSum 5 [7,8,9,10,1,2,3,4,6]
val get2 = subsetSum 5 [7,8,9,10,6]
val get3 = subsetSum 5 [1,2,3,4,6,7,8,9,10,7,8,9,10,1,2,3,4,6]
val get4 = subsetSum 5 [1,2,3,4,6,7,8,9,10,5,7,8,9,10,1,2,3,4,6]
*)

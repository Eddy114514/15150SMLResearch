(* @solution *)
(* heads : int * int list -> int
 * REQUIRES: true
 * ENSURES: heads (x, xs) ==> the largest n such that the first n elements of xs
 * are all equal to x
 *)
fun heads (x : int, [] : int list) : int = 0
  | heads (x : int, h::hs : int list) : int = 
    case x = h of 
    true => 1 + heads(x,hs)
   |false => 0

(* TEST CASES *)
(* Uncomment to test *)
val () = Test.int ("heads: test case 1", 2, heads (1,[1,1,2,1,3]))
val () = Test.int ("heads: test case 2", 0, heads (2,[1,1,2,1,3]))
(* Write more test cases here *)


(* tails : int * int list -> int list
 * REQUIRES: true
 * ENSURES: tails (x, xs) ==> xs with the first k elements removed, where
 * k = heads (x, xs)
 *)
fun tails (x : int, [] : int list) : int list = []
  | tails (x : int, h::hs : int list) : int list = 
    case x = h of
    true => tails(x,hs)
   |false => h::hs

(* TEST CASES *)
(* Uncomment to test *)
val () = Test.int_list_eq ("tails: test case 1", [2,1,3], tails(1,[1,1,2,1,3]))
val () = Test.int_list_eq ("tails: test case 2", [1,1,2,1,3], tails(2,[1,1,2,1,3]))
(* Write more test cases here *)


(* remove : int * int list -> int list
 * REQUIRES: true
 * ENSURES: remove (x, xs) ==> xs' such that xs' does not contain any element
 * y such that y = x, and xs' contains exactly all elements in xs except for x
 * in the same order as they were in xs
 *)
fun remove (x : int, [] : int list) : int list = []
  | remove (x : int, h::hs : int list) : int list =
    case x = h of 
    true => remove(x,hs)
   |false => h::remove(x,hs)

(* TEST CASES *)
(* Uncomment to test *)
val () = Test.int_list_eq ("remove: test case 1", [2,3], remove(1,[1,1,2,1,3]))
val () = Test.int_list_eq ("remove: test case 2", [1,1,1,3], remove(2,[1,1,2,1,3]))
val () = Test.int_list_eq ("remove: test case 3", [1,5,1,5,0], remove(3,[1,5,1,5,0]))
val () = Test.int_list_eq ("remove: test case 3", [1,5,1,5], remove(0,[0,1,0,5,0,1,0,5,0]))
(* Write more test cases here *)


(* partition : int * int list -> int list * int list
 * REQUIRES: true
 * ENSURES: partition (pivot, L) ==> (L1, L2) such that
 *          for all x in L1, x <= pivot and
 *          for all y in L2, pivot < y.
 *)
fun partition (pivot : int, [] : int list) : int list * int list = ([],[])
  | partition (pivot : int, x::xs : int list) : int list * int list =
  let
    val(L1,L2) = partition(pivot, xs)
  in 
    case x <= pivot of 
      true => (x::L1,L2)
     |false => (L1,x::L2) 
  end  

(* TEST CASES *)
(* Uncomment to test *)
val () =
  Test.int_list_int_list ("partition: test case 1", ([1,0],[3,4,5]), partition (2,[1,3,4,0,5]))

 val () =
  Test.int_list_int_list ("partition: test case 2", ([1,2,3,0],[]), partition (3,[1,2,3,0]))
(* Write more test cases here *)
(* @manual hw_remove *)
(* @contract remove
 * remove : int * int list -> int list
 * REQUIRES: true
 * ENSURES: Retain exactly the occurrences not equal to x, in input order.
 *)
functor ManualContract (Helpers : sig end) = struct
  type input = int * int list
  type output = int list
  fun requires (_ : input) = true
  fun ensures (x, xs) (result : output) =
    result = List.filter (fn y => y <> x) xs
end
(* @manual hw_heads *)
(* @contract heads
 * heads : int * int list -> int
 * REQUIRES: true
 * ENSURES: Return the maximum length of the initial all-x prefix.
 *)

functor ManualContract (Helpers : sig end) = struct
  type input = int * int list
  type output = int
  fun requires (_ : input) = true
  fun ensures (x, xs) k =
    k >= 0 andalso k <= List.length xs
    andalso List.all (fn y => y = x) (List.take (xs, k))
    andalso (k = List.length xs orelse List.nth (xs, k) <> x)
end

(* @manual hw_tails *)
(* @contract tails
 * tails : int * int list -> int list
 * REQUIRES: true
 * ENSURES: Remove the maximum all-x prefix; its length is heads (x,xs).
 * Preserve the entire remaining suffix in its original order.
 *)
 
functor ManualContract (Helpers : sig
  val heads : int * int list -> int
end) = struct
  type input = int * int list
  type output = int list
  fun requires (_ : input) = true

  (* Independent relation, not a second invocation of the student's helper. *)
  fun maximalSuffix (x, xs) result =
    let val cut = List.length xs - List.length result
    in cut >= 0
       andalso List.all (fn y => y = x) (List.take (xs, cut))
       andalso List.drop (xs, cut) = result
       andalso (null result orelse hd result <> x)
    end

  fun ensures (input as (_, xs)) result =
    let val k = Helpers.heads input
    in k >= 0 andalso k <= List.length xs
       andalso result = List.drop (xs, k)
       andalso maximalSuffix input result
    end
end

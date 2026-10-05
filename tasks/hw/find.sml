(* Original solution: 15150HW/HWANS/238860659/code/findn/findn.sml. *)
(* @solution *)
datatype 'a shrub = Leaf of 'a
                  | Branch of 'a shrub * 'a shrub

(* findOne : ('a -> bool) -> 'a shrub -> ('a -> 'b) -> (unit -> 'b) -> 'b
 * REQUIRES: p is total
 * ENSURES:  findOne p T sc fc ==> sc x if x is in T and p x ==> true.
 *           If no such x exists, this evalutes to fc () instead.
 *           If more than one such x exists,
 *           findOne p T sc fc evaluates the leftmost such x.
 *)
fun findOne (p : 'a -> bool) (Leaf(x) : 'a shrub)
            (sc : 'a -> 'b) (fc : unit -> 'b) : 'b = if p x then sc x else fc ()
  | findOne p (Branch(x,y)) sc fc = findOne p x sc (fn () => findOne p y sc fc)

(*
val T = Branch ( Leaf 1 , Leaf 2)
val p = fn x => x > 0
val sc = SOME
val fc = fn () => NONE
val ans1 = findOne p T sc fc
val p0 = fn x => x = 0
val p2 = fn x => x = 2
val ans2 = findOne p2 T sc fc
val ans3 = findOne p0 T sc fc
*)





(* findTwo : ('a -> bool) -> ('a * 'a -> bool) -> 'a shrub
 *           -> ('a * 'a -> 'b) -> (unit -> 'b) -> 'b
 * REQUIRES: p is total, eq is total, eq represents an equivalence relation
 * ENSURES:  findTwo p eq T sc fc ==> sc (x, y) if x and y are values in T s.t.
 *           p x ==> true and p y ==> true and eq (x,y) ==> false.
 *           If no such pair (x,y) exists, findTwo p T sc fc ==> fc ()
 *)
fun findTwo (p : 'a -> bool) (eq : 'a * 'a -> bool) (Leaf(x) : 'a shrub)
            (sc : 'a * 'a -> 'b) (fc : unit -> 'b) : 'b  = fc ()
  | findTwo p eq rub sc fc = 
  let
    
    val newSc = fn x => findOne (fn y => p(y) andalso not (eq(x,y))) rub (fn z => sc(x,z)) fc
  in
    findOne p rub newSc fc
  end

(*
val T1 = Branch ( Leaf 1 , Leaf 2)
val T2 = Branch ( Leaf 1 , Leaf 1)
val p1 = fn x => x > 0
val p2 = fn x => x = 1
val eq : int * int -> bool = op=
val sc = SOME
val fc = fn () => NONE

val () = Test.option (op= , MakeString.int_int )
(" findTwo p1 T1", SOME (1 , 2) , findTwo p1 eq T1 sc fc )
val () = Test.option (op= , MakeString.int_int )
(" findTwo p2 T1", NONE , findTwo p2 eq T1 sc fc )
val () = Test.option (op= , MakeString.int_int )
(" findTwo p1 T2", NONE , findTwo p1 eq T2 sc fc )
*)
  


(* findN : ('a -> bool) -> ('a * 'a -> bool) -> 'a shrub -> int
 *         -> ('a list -> 'b) -> (unit -> 'b) -> 'b
 * REQUIRES: n >= 0, p is total, eq is total,
 *           eq represents an equivalence relation
 * ENSURES: findN p eq T n sc fc ==> sc L if there exists
 *          a list L of length n s.t the elements in L are pairwise distinct
 *          by eq, and for each element x in L, p x ==> true.
 *          Otherwise evaluates to fc ().
 *)
fun findN (p : 'a -> bool) (eq : 'a * 'a -> bool) (T : 'a shrub)
          (n : int) (sc : 'a list -> 'b) (fc : unit -> 'b) =
  (case n of
      0 => sc []
    | _ =>
        let
          fun success x =
            let
              val ssc = fn alist => sc (x::alist)
              val pp = fn y => p(y) andalso not (eq(y,x))
            in
              findN pp eq T (n-1) ssc fc
            end
        in
          findOne p T success fc
        end)

(*
val T1 = Branch(Branch(Branch(Leaf(3),Leaf(2)),Leaf(2)),Branch(Leaf(4),Branch(Leaf(7),Leaf(5))))
val T2 = Branch ( Leaf 1 , Leaf 1)
val p1 = fn x => x > 0
val p2 = fn x => x = 1
val eq : int * int -> bool = op=
val sc = SOME
val fc = fn () => NONE

val res1 = findN p1 eq T1 5 sc fc
*)
(* @manual hw_find_one *)
(* @contract hw_find_one
 * Original: ('a -> bool) -> 'a shrub -> ('a -> 'b) -> (unit -> 'b) -> 'b.
 * Concrete total predicate family, int leaves, SOME/NONE continuations.
 *)
functor ManualContract (Helpers : sig end) = struct
  type input = CpsCase.predicate * CpsCase.tree
  type output = int option
  fun requires (_ : input) = true
  fun ensures (p,t) result = result = List.find (CpsCase.test p) (CpsModel.leaves t)
end
(* @manual hw_find_n *)
(* @contract hw_find_n
 * Original: ('a -> bool) -> ('a * 'a -> bool) -> 'a shrub -> int
 *           -> ('a list -> 'b) -> (unit -> 'b) -> 'b.
 * Tree membership is the agreed search domain (also explicit for findTwo).
 * Any ordered listing of n distinct admissible leaves is allowed.
 *)
functor ManualContract (Helpers : sig end) = struct
  type input = CpsCase.predicate * CpsCase.equality * CpsCase.tree * int
  type output = int list option
  fun requires (_,_,_,n) = n >= 0
  fun ensures (p,e,t,n) result =
    let val candidates = List.filter (CpsCase.test p) (CpsModel.leaves t)
        val eq = CpsCase.equivalent e
    in case result of
         NONE => List.length (CpsModel.classes eq candidates) < n
       | SOME xs => List.length xs = n andalso CpsModel.distinct eq xs andalso
           List.all (fn x => List.exists (fn y => x = y) candidates) xs
    end
end

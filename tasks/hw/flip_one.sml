(* @solution *)
(* addB: bool * bool bool list -> bool list list
 * REQUIRES: true
 * ENSURES: add b to every bool list within the bool list list
 *)

fun addB (b:bool, []: bool list list) : bool list list = []
  | addB (b:bool, bl::bll: bool list list) : bool list list = (b::bl)::addB(b,bll)

(* flipOne: bool list -> bool list list
 * REQUIRES: true
 * ENSURES: flipOne L ==>* An ordered list containing all the ways to flip exactly
 *          one true to false.
 *)

fun flipOne ([] : bool list) : bool list list = []
  | flipOne (true::bs : bool list): bool list list = (false::bs)::addB(true,flipOne(bs))
  | flipOne (false:: bs : bool list): bool list list = addB(false,flipOne(bs))

(* @manual hw_flip_one *)
(* @contract hw_flip_one
 * flipOne : bool list -> bool list list
 * REQUIRES: true
 * ENSURES: Each output flips exactly one true input position to false and
 * preserves every other position. Each eligible position occurs exactly once.
 * The original PDF permits any order of the output lists.
 *)
functor ManualContract (Helpers : sig end) = struct
  type input = bool list
  type output = bool list list
  fun requires (_ : input) = true

  fun changedIndex xs ys =
    let fun scan _ ([],[]) changed = changed
          | scan i (x::xs,y::ys) changed =
              if x = y then scan (i+1) (xs,ys) changed
              else if x andalso not y then
                (case changed of NONE => scan (i+1) (xs,ys) (SOME i)
                               | SOME _ => NONE)
              else NONE
          | scan _ _ _ = NONE
    in scan 0 (xs,ys) NONE end

  fun ensures xs result =
    let val positions = List.tabulate (List.length xs,fn i => i)
        val eligible = List.mapPartial
          (fn (i,b) => if b then SOME (SOME i) else NONE)
          (ListPair.zip (positions,xs))
    in Spec.sameMultiset (List.map (changedIndex xs) result,eligible) end
end

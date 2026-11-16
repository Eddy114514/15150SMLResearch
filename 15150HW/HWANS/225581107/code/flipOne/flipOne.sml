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
  



(* TEST CASES *)
(* Uncomment to test *)

(* Exactly one of the following two test cases should pass: *)
val () = Test.bool_list_list_eq ("two trues", [[false, true], [true, false]], flipOne [true, true])

(* Both of the following should pass: *)
val () = Test.bool_list_list_eq ("one true", [[false, false]], flipOne [false, true])
val () = Test.bool_list_list_eq ("no trues", [], flipOne [])

(* Write more test cases here *)

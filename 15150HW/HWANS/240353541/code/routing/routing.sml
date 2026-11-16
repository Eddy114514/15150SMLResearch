datatype regexp =
    Zero
  | One
  | Char of char
  | Plus of regexp * regexp
  | Times of regexp * regexp
  | Star of regexp

(* This implementation of match also works on
 * regular expressions that aren't in standard form. *)
fun match (Zero) _ _ = false
  | match (One) cs k = k cs
  | match (Char(a)) cs k = (case cs of
                              nil => false
                            | (c::cs') => (a=c) andalso (k cs'))
  | match (Plus(r1,r2)) cs k = match r1 cs k orelse match r2 cs k
  | match (Times(r1,r2)) cs k = match r1 cs (fn cs' => match r2 cs' k)
  | match (Star(r)) cs k =
       k cs orelse
       match r cs (fn cs' => length cs' < length cs andalso match (Star(r)) cs' k)

fun accept r s = match r (String.explode s) List.null



type command_sequence = string  (* command sequence *)

(* example *)
val cmu_to_waterfront : command_sequence = "ES"

val sqh_loop_1 : command_sequence = "SN"
val sqh_loop_2 : command_sequence = "WE"

val cmu_to_airport_1 : command_sequence = "W"  (* REPLACE ME *)
val cmu_to_airport_2 : command_sequence = "ESW"  (* REPLACE ME *)

local
  val N = Char #"N"
  val S = Char #"S"
  val E = Char #"E"
  val W = Char #"W"
  val op + = Plus
  val op * = Times
in
  val sqh_to_sqh : regexp = Star((S*N) + (W*E))

  val cmu_to_airport : regexp = Star(E*(Star(W*E)+Star(S*N))*(W+S)) * W

end


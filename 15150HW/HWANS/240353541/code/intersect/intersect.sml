datatype regexp =
    Zero
  | One
  | Char of char
  | Plus of regexp * regexp
  | Times of regexp * regexp
  | Star of regexp
  | Both of regexp * regexp

(* match : regexp -> char list -> (char list -> bool) -> bool
 * REQUIRES:  r is in standard form, k is total.
 * ENSURES: match r cs k == true iff there is a split p@s==cs such that
 *            p is in language of r and k s == true.
 *)
fun match (r : regexp) (cs : char list) (k : char list -> bool) : bool =
    case r of
      Zero => false
    | One => k cs
    | Char c => (case cs of
                   []  => false
                 | c' :: cs' => c' = c andalso k cs')
    | Plus (r1,r2) => match r1 cs k orelse match r2 cs k
    | Times (r1,r2) => match r1 cs (fn cs' => match r2 cs' k)
    | Star r =>
      let
        fun matchrstar cs' = k cs' orelse match r cs' matchrstar
      in
        matchrstar cs
      end
    (* TODO: Replace badBoth with a correct implementation *)
    | Both (r1,r2) => match r1 cs (fn rm1 => match r2 cs (fn rm2 => rm1 = rm2 andalso k(rm2)))
        
(* badBoth: regexp -> regexp -> char list -> (char list -> bool) -> bool
* REQUIRES: (standard requirements as for match)
* ENSURES: badBoth r1 r2 cs k evalutes to true iff there exist values p,s
* such that p@s is equivalent to cs, p is in L(Both(r1,r2)), and k s is
* true.
*)
and badBoth (r1 : regexp) (r2 : regexp) (cs : char list)
  (k : char list -> bool) : bool =
  (match r1 cs k) andalso (match r2 cs k)

(* accept : regexp -> string -> bool
 * REQUIRES: r is in standard form.
 * ENSURES: accept r s   evaluates to true if and only if s is in the
 *          language of r *)
fun accept r s = match r (String.explode s) List.null

(* Tests... *)
local
  val r1 = Times(Char #"f", Times(Char #"u", Char #"n"))
  val r2 = Times(Times(Char #"f", Char #"u"), Times(Char #"n", Char #"c"))
  val badB = Both(r1,r2)

  val gr1 = Plus(Char #"f", Plus(Char #"u", Char #"n"))
  val gr2 = Plus(Plus(Char #"f", Char #"u"), Plus(Char #"n", Char #"c"))
in
  val res = match badB (String.explode "un") (fn x => true)
  val gres = match (Both(gr1,gr2)) (String.explode "func") (fn x => true)
end

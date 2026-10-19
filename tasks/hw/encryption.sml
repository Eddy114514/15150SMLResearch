(* @solution *)
type 'a key = ('a -> exn) * (exn -> 'a option)

(* new : unit -> 'a key
 * REQUIRES: true
 * ENSURES: new () ==> k such that (decrypt k o encrypt k) = SOME
 *          and for all k' /= k we have
 *          (decrypt k' o encrypt k) = (decrypt k o encrypt k') = fn _ => NONE
 *)
fun new () = let
  exception NEW of 'a
in
  (NEW, fn NEW(x) => SOME(x) | _ => NONE)
end

(* encrypt : 'a key -> 'a -> exn
 * REQUIRES: true
 * ENSURES: If encrypt k x ==> y then decrypt k y ==> SOME x
 *)
fun encrypt ((enc, _) : 'a key) = enc

(* decrypt : 'a key -> exn -> 'a option
 * REQUIRES: true
 * ENSURES: decrypt k x ==> SOME y   if encrypt k y evaluated to x
 *                          NONE     otherwise
 *)
fun decrypt ((_, dec) : 'a key) = dec

(* @manual hw_encryption *)
(* @contract new
 * new : unit -> 'a key
 * REQUIRES: true.
 * ENSURES: A matching key recovers the original payload. Distinct calls create
 * keys that reject each other's secrets, even at the same payload type.
 * The observations also check repeated use and preservation of earlier secrets
 * after later key creation. Function payloads are observed at finite probes.
 *)
functor ManualContract (Helpers : sig end) = struct
  type input = EncryptionCase.input
  type output = EncryptionCase.output
  fun requires (_ : input) = true

  fun absent NONE = true
    | absent (SOME _) = false
  (* Only ordinary observed data are compared, never keys, exn, or functions. *)
  fun matches (x,y,z) ({matrix,reused,foreign} : ''a EncryptionCase.observations) =
    matrix = [[SOME x,NONE,NONE],
              [NONE,SOME y,NONE],
              [NONE,NONE,SOME z]] andalso
    reused = List.map SOME [x,y,z] andalso
    List.length foreign = 9 andalso List.all absent foreign

  fun ensures ({integers,strings,lists,functions=(f,g,h),probes} : input)
              (result : output) = let
    fun observed description = List.map (EncryptionCase.affine description) probes
  in
    matches integers (#integers result) andalso
    matches strings (#strings result) andalso
    matches lists (#lists result) andalso
    matches (observed f,observed g,observed h) (#functions result)
  end
end

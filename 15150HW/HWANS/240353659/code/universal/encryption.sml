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

val k1 : string key = new ()
val k2 : int key = new ()
val k3 : string key = new ()
val hidden = encrypt k1 " hello !"
val () = Test.string_option (" test1 ", SOME " hello !", decrypt k1
hidden )
val () = Test.int_option (" test2 ", NONE , decrypt k2 hidden )
val () = Test.string_option (" test3 ", NONE , decrypt k3 hidden )
val () = Test.int_option (" test4 ", SOME 7 , decrypt k2 ( encrypt k2 7)
)
val () = Test.string_option (" test5 ", NONE , decrypt k1 ( encrypt k2
7) )


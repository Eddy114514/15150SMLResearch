structure StreamRand : STREAMRAND =
struct
  fun bbs m s = Stream.delay (fn () => bbs' m s)
  and bbs' m s = 
  let
    val new = (s*s) mod m
  in
    Stream.Cons(new, bbs m new)
  end

end

fun checkElem (expected, s) =
  (case Stream.expose s of
    Stream.Empty => raise Fail
      ("Empty Stream, Expected S.Cons(" ^ Int.toString expected ^ ", ...)")
  | Stream.Cons (first, s') =>
      let
        val () = Test.int ("Should Have Exposed " ^ Int.toString expected, expected, first)
      in
        s'
      end)

val s0 = StreamRand.bbs 15 3
val s1 = checkElem (9, s0)
val s2 = checkElem (6, s1)
val s3 = checkElem (6, s2)
val s1 = StreamRand.bbs (11 * 19) 3
(* Expose the first six elems of s1 *)
val () = Test.int_list_eq("test", [9,81,82,36,42,92], Stream.take (s1,6))

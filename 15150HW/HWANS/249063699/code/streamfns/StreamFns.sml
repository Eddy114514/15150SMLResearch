structure StreamFns :> STREAMFNS =
struct
  structure S = Stream

  (* concat: 'a Stream.t Stream.t -> 'a Stream.t
   * REQUIRES: s is productive
   * ENSURES:
   *     - concat s = s', a stream containing the elements of s concatenated
   *       together.
   *     - concat s is maximally lazy (evaluating concat s never exposes any
   *       elements of s).
   *)
  fun concat s = Stream.delay (fn () => concat' (Stream.expose s))
  and concat' Stream.Empty = Stream.Empty
    | concat' (Stream.Cons(x, s)) = Stream.expose(Stream.append(x, concat s))



  (* cycle: 'a Stream.t -> 'a Stream.t
   * REQUIRES: s is productive
   * ENSURES:
   *     - cycle s is productive
   *     - cycle s = s', a stream formed by infinitely repeating the elements of s
   *     - if s = Stream.empty, then cycle s = Stream.empty
   *     - cycle s is maximally lazy (evaluating cycle s never exposes any
   *       elements of s).
   *)
  fun cycle s = Stream.delay(fn () => Stream.expose(cycle' s))
  and cycle' s = if Stream.null s then Stream.empty else Stream.append(s, cycle s)

  (* interleave: 'a Stream.t -> 'a Stream.t -> 'a Stream.t
   * REQUIRES: s1 and s2 are productive
   * ENSURES:
   *     - interleave s1 s2 is productive
   *     - interleave s1 s2 = s, where s contains alternating elements from s1
   *       and s2, starting with the first element of s1
   *     - If one stream ends early, the rest of the other stream is appended in its entirety
   *     - interleave s1 s2 is maximally lazy (evaluating interleave s1 s2
   *       never exposes any elements of s1 or s2).
   *)
  fun interleave s1 s2 = Stream.delay(fn () => interleave' (Stream.expose s1) (Stream.expose s2))
  and interleave' Stream.Empty Stream.Empty = Stream.Empty
    | interleave' Stream.Empty p = p
    | interleave' p Stream.Empty = p
    | interleave' (Stream.Cons(x1, s1')) (Stream.Cons(x2,s2')) = 
      Stream.Cons(x1, 
        Stream.delay (fn () => Stream.Cons(x2, interleave s1' s2'))
      )

  (* double: 'a Stream.t -> 'a Stream.t
   * REQUIRES: s is productive
   * ENSURES:
   *     - double s is productive
   *     - double s = s', a stream containing the same elements as s, but with each
   *       element appearing twice in a row
   *     - double s is maximally lazy (evaluating double s never exposes any
   *       elements of s).
   *)
  fun double s = Stream.delay(fn () => double' (Stream.expose s))
  and double' Stream.Empty = Stream.Empty
    | double' (Stream.Cons(x, s)) = Stream.Cons(x, 
        Stream.delay (fn () => Stream.Cons(x, double s))
      )
end

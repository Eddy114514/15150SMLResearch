signature STREAM =
sig
  type 'a stream   (* abstract *)
  datatype 'a front = Empty | Cons of 'a * 'a stream
  type 'a t = 'a stream

  exception EmptyStream


  (* Lazy Stream Delay and Exposure *)
  (*!
   * `delay f` evaluates to a stream version of the suspended front.
   *)
  val delay : (unit -> 'a front) -> 'a stream
  (*!
   * `expose s` evaluates to a front version of the stream.
   *)
  val expose : 'a stream -> 'a front


  (* Stream Construction *)
  (*!
   * `empty` is a stream with no elements.
   *)
  val empty : 'a stream
  (*!
   * `cons (x,s)` evaluates to a stream whose first item is `x` and whose
   *    remaining items are exactly the stream `s`.
   *
   * Not to be confused with the constructor `Cons`.
   *)
  val cons : 'a * 'a stream -> 'a stream
  (*!
   * `fromList lst` returns a stream consisting of the elements of `lst`,
   *    preserving order. This function is intended primarily for debugging
   *    purposes.
   *)
  val fromList : 'a list -> 'a stream
  (*!
   * `tabulate f` evaluates to a stream `s` where the ith element of `s` is
   *    equal to `f i`.
   *
   * Note that indices are zero-indexed.
   *)
  val tabulate : (int -> 'a) -> 'a stream


  (* Deconstructing a Stream *)
  (*!
   * `null s` evaluates to `true` if `s` is an empty stream, and `false`
   *    otherwise.
   *)
  val null : 'a stream -> bool
  (*!
   * `hd s` evaluates to the first element of `s` if `s` is non-empty. `hd s`
   *    raises `EmptyStream` otherwise.
   *)
  val hd : 'a stream -> 'a
  (*!
   * `take (s, i)` evaluates to the list containing exactly the first `i`
   *    elements of `s` if `s` contains at least `i` elements, and raises `Subscript` otherwise.
   *)
  val take : 'a stream * int -> 'a list
  (*!
   * `toList s` returns a list consisting of the elements of `s`, preserving
   *    order. This function will loop forever if `s` is an infinite stream.
   *    This function is intended primarily for debugging purposes.
   *)
  val toList : 'a stream -> 'a list


  (* Simple Transformations *)
  (*!
   * `tl s` evaluates to the stream containing all but the first element of `s`
   *    if `s` is non-empty. `tl s` raises `EmptyStream` otherwise.
   *)
  val tl : 'a stream -> 'a stream
  (*!
   * `drop (s, i)` evaluates to the stream containing all but the first `i`
   *    elements of `s` if `s` contains at least `i` elements, and raises
   *    `Subscript` otherwise.
   *)
  val drop : 'a stream * int -> 'a stream
  (*!
   * `append (s1,s2)` evaluates to `s`, where `s` is `s2` appended to `s1`.
   *)
  val append : 'a stream * 'a stream -> 'a stream


  (* Combinators and Higher-Order Functions *)
  (*!
   * `map f s` evaluates to `s'`, where each element `x` in `s` corresponds to
   *    `f x` in `s'`.
   *)
  val map : ('a -> 'b) -> 'a stream -> 'b stream
  (*!
   * `filter p s` evaluates to a stream containing all of the elements `x` of
   *    `s` such that `p x` evaluates to `true`, preserving element order.
   *)
  val filter : ('a -> bool) -> 'a stream -> 'a stream
  (*!
   * `zip (s1,s2)` evaluates to `s'`, where the ith element of `s'` is the pair
   *    of the ith element of `s1` and the ith element of `s2`.
   *
   * `s'` contains as many elements as the stream (`s1` or `s2`) with fewer
   *    elements.
   *)
  val zip : 'a stream * 'b stream -> ('a * 'b) stream

end

(* @solution *)
structure StreamFns :> STREAMFNS =
struct
  structure S = Stream

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

end
(* @manual hw_lazy_cycle *)
(* @contract lazy_cycle
 * StreamFns.cycle : 'a Stream.t -> 'a Stream.t
 * REQUIRES: The input stream is productive; every LazyCase.source is productive.
 * ENSURES: Repeat a nonempty finite input forever; preserve an infinite input;
 * empty input stays empty. Construction exposes no input front.
 * This int instance observes at most max(0,probes) output fronts, stopping at Empty.
 *)
functor ManualContract (Helpers : sig end) = struct
  type input = LazyCase.source * int
  type output = int * int option list
  fun requires (_ : input) = true
  fun ensures (source,probes) (constructionForces,fronts) =
    constructionForces = 0 andalso
    fronts = LazyModel.observe (LazyModel.cycleAt source) probes
end
(* @manual hw_lazy_interleave *)
(* @contract lazy_interleave
 * StreamFns.interleave : 'a Stream.t -> 'a Stream.t -> 'a Stream.t
 * REQUIRES: Both input streams are productive; the source descriptions ensure this.
 * ENSURES: Alternate starting on the left, then retain all of the surviving stream.
 * Construction exposes no input front. If the left stream is nonempty, observing
 * only the first output must not expose the right stream (PDF maximal laziness).
 * Observe at most max(0,probes) output fronts.
 * An observed Empty ends the finite observation; premature Empty is a failure.
 *)
functor ManualContract (Helpers : sig end) = struct
  type input = LazyCase.source * LazyCase.source * int
  type output = int * int * int option list
  fun requires (_ : input) = true
  fun ensures (left,right,probes) (constructionForces,firstRightForces,fronts) =
    constructionForces = 0 andalso
    firstRightForces >= 0 andalso
    (probes > 0 orelse firstRightForces = 0) andalso
    (probes <= 0 orelse LazyModel.at left 0 = NONE orelse firstRightForces = 0) andalso
    fronts = LazyModel.observe (LazyModel.interleaveAt (left,right)) probes
end

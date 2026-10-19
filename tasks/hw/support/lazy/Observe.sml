(* Thin use of the course Stream API. New counters and streams are built for
 * each target call. The wrappers capture the specific exposure events checked. *)
structure LazyObserve = struct
  fun build source forces = let
    fun finite [] = Stream.delay (fn () => (forces := !forces + 1; Stream.Empty))
      | finite (x::xs) = Stream.delay
          (fn () => (forces := !forces + 1; Stream.Cons (x,finite xs)))
    fun periodic period [] = periodic period period
      | periodic period (x::xs) = Stream.delay
          (fn () => (forces := !forces + 1; Stream.Cons (x,periodic period xs)))
  in
    case source of LazyCase.Finite xs => finite xs
    | LazyCase.Repeat (first,rest) => periodic (first::rest) (first::rest)
  end

  fun fronts probes stream = let
    fun loop 0 _ = []
      | loop n s =
          case Stream.expose s of
            Stream.Empty => [NONE]
          | Stream.Cons (x,rest) => SOME x :: loop (n-1) rest
  in loop (Int.max (0,probes)) stream end
end

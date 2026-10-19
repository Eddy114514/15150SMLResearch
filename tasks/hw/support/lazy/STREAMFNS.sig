signature STREAMFNS =
sig
  val cycle: 'a Stream.t -> 'a Stream.t
  val interleave: 'a Stream.t -> 'a Stream.t -> 'a Stream.t
end

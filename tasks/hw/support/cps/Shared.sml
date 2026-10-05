(* External finite description; Target's generative shrub datatype is constructed
 * recursively at runtime, not made visible to the independent contracts. *)
structure CpsCase = struct
  datatype tree = Tip of int | Fork of tree * tree
  datatype predicate = Any | Even | Positive | Equals of int
  datatype equality = Exact | Parity
  fun test Any _ = true
    | test Even x = x mod 2 = 0
    | test Positive x = x > 0
    | test (Equals y) x = x = y
  fun equivalent Exact (x:int,y) = x = y
    | equivalent Parity (x,y) = x mod 2 = y mod 2
end

(* Independent finite observations shared by sorting and grouping contracts.
 * Equality is element identity; cmp-EQUAL may identify a larger class. *)
structure OrderSpec = struct
  fun strictlyOrdered cmp [] = true
    | strictlyOrdered cmp [_] = true
    | strictlyOrdered cmp (x :: y :: rest) =
        cmp (x,y) = LESS andalso strictlyOrdered cmp (y :: rest)

  fun keyCompare ((x,_) : int * int, (y,_) : int * int) = Int.compare (x,y)
end

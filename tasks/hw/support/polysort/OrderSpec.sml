(* Independent finite observations shared by sorting and grouping contracts.
 * Equality is element identity; cmp-EQUAL may identify a larger class. *)
structure OrderSpec = struct
  fun removeOne eq x [] = NONE
    | removeOne eq x (y :: ys) =
        if eq (x,y) then SOME ys
        else Option.map (fn rest => y :: rest) (removeOne eq x ys)

  fun sameBag eq ([], ys) = List.null ys
    | sameBag eq (x :: xs, ys) =
        case removeOne eq x ys of
          NONE => false
        | SOME rest => sameBag eq (xs, rest)

  fun ordered cmp [] = true
    | ordered cmp [_] = true
    | ordered cmp (x :: y :: rest) =
        cmp (x,y) <> GREATER andalso ordered cmp (y :: rest)

  fun strictlyOrdered cmp [] = true
    | strictlyOrdered cmp [_] = true
    | strictlyOrdered cmp (x :: y :: rest) =
        cmp (x,y) = LESS andalso strictlyOrdered cmp (y :: rest)

  fun keyCompare ((x,_) : int * int, (y,_) : int * int) = Int.compare (x,y)
end

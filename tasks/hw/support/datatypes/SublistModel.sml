structure SublistModel = struct
  fun subsequence [] _ = true
    | subsequence _ [] = false
    | subsequence (ys as y::rest) (x::xs) =
        if y = x then subsequence rest xs else subsequence ys xs
  fun sum xs = List.foldl (fn (x, n) => IntInf.fromInt x + n) 0 xs

  (* Enumerate sums of selections of finite positions; no bound in semantics. *)
  fun selectionSums [] = [0 : IntInf.int]
    | selectionSums (x::xs) =
        let val sums = selectionSums xs
        in sums @ List.map (fn n => IntInf.fromInt x + n) sums end

end

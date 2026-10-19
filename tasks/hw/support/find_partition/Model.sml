(* Enumerate the definition's positional partitions. No target or CPS search. *)
structure PartitionModel = struct
  fun partitions xs = List.foldr
    (fn (x,pairs) => List.concat
      (List.map (fn (left,right) => [(x::left,right),(left,x::right)]) pairs))
    [([],[])] xs

  fun evidence (xs,pLeft,pRight) = List.mapPartial
    (fn (left,right) =>
      if PartitionCase.accepts pLeft left andalso PartitionCase.accepts pRight right
      then SOME (left,PartitionCase.summary right) else NONE)
    (partitions xs)
end

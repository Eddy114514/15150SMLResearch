structure PartitionCase = struct
  datatype predicate = Sum of IntInf.int | Length of int | All of CpsCase.predicate
  type input = int list * predicate * predicate
  type evidence = int list * (int * IntInf.int)
  type output = evidence option

  fun sum xs = List.foldl (fn (x,n) => IntInf.fromInt x + n) 0 xs
  fun accepts (Sum n) xs = sum xs = n
    | accepts (Length n) xs = List.length xs = n
    | accepts (All p) xs = List.all (CpsCase.test p) xs
  fun summary xs = (List.length xs,sum xs)
end

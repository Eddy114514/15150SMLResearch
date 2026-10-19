structure TargetAdapter = struct
  fun run (xs,pLeft,pRight) =
    let
      fun left values sc fc =
        if PartitionCase.accepts pLeft values then sc values else fc ()
      fun right values sc fc =
        if PartitionCase.accepts pRight values
        then sc (PartitionCase.summary values) else fc ()
    in Target.findPartition xs left right SOME (fn () => NONE) end
end

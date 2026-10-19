structure TargetAdapter = struct
  fun run (left,right,probes) = let
    val leftForces = ref 0
    val rightForces = ref 0
    val leftStream = LazyObserve.build left leftForces
    val rightStream = LazyObserve.build right rightForces
    val result = Target.StreamFns.interleave leftStream rightStream
    val constructionForces = !leftForces + !rightForces
    val (firstRightForces,fronts) =
      if probes <= 0 then (0,[])
      else let
        val front = Stream.expose result
        val firstRightForces = !rightForces
        val fronts = case front of Stream.Empty => [NONE]
          | Stream.Cons (x,rest) => SOME x :: LazyObserve.fronts (probes-1) rest
      in (firstRightForces,fronts) end
  in (constructionForces,firstRightForces,fronts) end
end

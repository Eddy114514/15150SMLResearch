structure TargetAdapter = struct
  fun run (source,probes) = let
    val forces = ref 0
    val input = LazyObserve.build source forces
    val result = Target.StreamFns.cycle input
    val constructionForces = !forces
    val fronts = LazyObserve.fronts probes result
  in (constructionForces,fronts) end
end

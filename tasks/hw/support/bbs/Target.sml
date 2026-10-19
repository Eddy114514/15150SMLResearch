structure TargetAdapter = struct
  fun run (modulus,seed,probes) =
    LazyObserve.fronts probes (Target.StreamRand.bbs modulus seed)
end

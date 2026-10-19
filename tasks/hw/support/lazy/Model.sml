(* Independent index semantics. No Stream construction, exposure, or Target calls. *)
structure LazyModel = struct
  fun finiteLength (LazyCase.Finite xs) = SOME (List.length xs)
    | finiteLength (LazyCase.Repeat _) = NONE

  fun at (LazyCase.Finite xs) i =
        if i < List.length xs then SOME (List.nth (xs,i)) else NONE
    | at (LazyCase.Repeat (first,rest)) i =
        let val period = first::rest
        in SOME (List.nth (period,i mod List.length period)) end

  fun cycleAt (LazyCase.Finite []) _ = NONE
    | cycleAt (LazyCase.Finite xs) i = SOME (List.nth (xs,i mod List.length xs))
    | cycleAt (source as LazyCase.Repeat _) i = at source i

  fun interleaveAt (left,right) i = let
    fun alternate () = if i mod 2 = 0 then at left (i div 2) else at right (i div 2)
    fun after common survivor consumed =
      if i div 2 < common then alternate () else at survivor (i-consumed)
  in
    case (finiteLength left,finiteLength right) of
      (NONE,NONE) => alternate ()
    | (SOME n,NONE) => after n right n
    | (NONE,SOME n) => after n left n
    | (SOME m,SOME n) =>
        if m <= n then after m right m else after n left n
  end

  (* A probe observes one front. NONE records actual termination, including
   * termination immediately after the last value if the probe count allows it. *)
  fun observe valueAt probes = let
    val count = Int.max (0,probes)
    fun loop i =
      if i = count then []
      else case valueAt i of NONE => [NONE] | SOME x => SOME x :: loop (i+1)
  in loop 0 end
end

structure TargetAdapter = struct
  (* Save the first secret before the two later, independent new calls.
   * Create several more secrets with k1 before reading any saved secret. *)
  fun prepare (x : 'a,y : 'a,z : 'a) = let
    val k1 : 'a Target.key = Target.new ()
    val first = Target.encrypt k1 x
    val k2 : 'a Target.key = Target.new ()
    val k3 : 'a Target.key = Target.new ()
    val secrets = [first,Target.encrypt k2 y,Target.encrypt k3 z]
    val reused = List.map (Target.encrypt k1) [x,y,z]
  in ([k1,k2,k3],secrets,reused) end

  (* Preserve option tags, including for function payloads. No exception handler. *)
  fun observe project (keys,secrets,reused) foreign = let
    val firstKey = hd keys
    fun decrypt key secret =
      Option.map project (Target.decrypt key secret)
  in
    {matrix = List.map (fn key => List.map (decrypt key) secrets) keys,
     reused = List.map (decrypt firstKey) reused,
     foreign = List.map (decrypt firstKey) foreign}
  end

  fun run ({integers,strings,lists,functions=(f,g,h),probes} : EncryptionCase.input) = let
    val ints as (_,intSecrets,_) = prepare integers
    val texts as (_,stringSecrets,_) = prepare strings
    val sequences as (_,listSecrets,_) = prepare lists
    val functions = prepare (Affine.apply f,Affine.apply g,Affine.apply h)
    val (_,functionSecrets,_) = functions
  in
    {integers = observe (fn x => x) ints (stringSecrets @ listSecrets @ functionSecrets),
     strings = observe (fn x => x) texts (intSecrets @ listSecrets @ functionSecrets),
     lists = observe (fn x => x) sequences (intSecrets @ stringSecrets @ functionSecrets),
     functions = observe (fn f => List.map f probes) functions
                   (intSecrets @ stringSecrets @ listSecrets)}
  end
end

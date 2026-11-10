(* Pure observations through Seq's public API, never Target functions. *)
structure SeqSpec = struct
  fun rectangular matrix =
    case Seq.toList matrix of
      [] => true
    | row :: rows => List.all (fn r => Seq.length r = Seq.length row) rows

  fun homogeneous cmp [] = false
    | homogeneous cmp (x :: xs) = List.all (fn y => cmp (x,y) = EQUAL) xs

  fun collect cmp input output = let
    val xs = Seq.toList input
    val groups = List.map Seq.toList (Seq.toList output)
    val members = List.concat groups
  in
    List.all (homogeneous cmp) groups andalso
    OrderSpec.strictlyOrdered cmp (List.map List.hd groups) andalso
    List.length members = List.length xs andalso
    List.all (fn x => List.exists (fn y => x = y) members) xs
  end

  fun unique cmp input output = let
    val xs = Seq.toList input
    val ys = Seq.toList output
    fun equivalentMember x values = List.exists (fn y => cmp (x,y) = EQUAL) values
  in
    OrderSpec.strictlyOrdered cmp ys andalso
    List.all (fn x => equivalentMember x ys) xs
  end
end

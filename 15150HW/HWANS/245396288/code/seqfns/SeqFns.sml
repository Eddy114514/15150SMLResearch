structure SeqFns :> SEQFNS =
struct
  (* exists: ('a -> bool) -> 'a Seq.t -> bool
   * REQUIRES: p is total
   * ENSURES:
   *   if there exists an element x in S such that p x ==> true
   *     then exists p S ==> true
   *     else exists p S ==> false
   *   exists p S has O(|S|) work and O(log|S|) span
   *     if p has O(1) work and span
   *)
  fun exists p xs = 
  let
    val get = Seq.filter p xs
  in
    not(Seq.null get)
  end

  (* transpose: 'a Seq.t Seq.t -> 'a Seq.t Seq.t
   * REQUIRES: S is a well-formed n x m matrix
   * ENSURES: transpose S ==> S' where
   *   if n = 0 then S' is the "trivial" matrix
   *   otherwise S' is a well-formed m x n matrix
   *   and forall i, j: S[i][j] ~= S'[j][i]
   *  transpose S has O(mn) work
   *  transpose S has O(1) span
   *)
  fun transpose xss =
  let
    (* O(|n|), Span: O(1) *)
    fun getCol n seq = Seq.map (fn xs => Seq.nth xs n) seq
    (* O(1) *)
    fun numCols xs = Seq.length (Seq.nth xs 0)
    
  in
    if Seq.null xss then xss
    (* O(|m|) with O(|n|) f, ==> O(|m*n|) *)
    (* SPAN, O(1), with f Span of O(1)*)
    else Seq.tabulate (fn i => getCol i xss) (numCols xss)
  end



end

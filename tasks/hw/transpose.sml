(* @solution *)
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
(* @manual hw_transpose *)
(* @contract transpose
 * Original: 'a Seq.t Seq.t -> 'a Seq.t Seq.t; here int elements.
 * REQUIRES: rectangular finite input. ENSURES: dimensions swap and every
 * S[i][j] equals T[j][i]. The accepted baseline resolves "trivial" to empty;
 * both empty outer input and nonzero rows of zero columns produce empty.
 * Functional projection only: the original work/span clauses are not checked.
 * No dimension or generator budget restricts requires.
 *)
functor ManualContract (Helpers : sig end) = struct
  type input = int Seq.t Seq.t
  type output = int Seq.t Seq.t
  fun requires (matrix : input) = SeqSpec.rectangular matrix
  fun ensures (matrix : input) (result : output) = let
    val rows = Seq.length matrix
  in
    if rows = 0 then Seq.length result = 0
    else let val cols = Seq.length (Seq.nth matrix 0)
    in
      Seq.length result = cols andalso
      Spec.forallRange (fn j => Seq.length (Seq.nth result j) = rows) (0,cols-1) andalso
      Spec.forallRange
        (fn i => Spec.forallRange
          (fn j => Seq.nth (Seq.nth matrix i) j = Seq.nth (Seq.nth result j) i)
          (0,cols-1)) (0,rows-1)
    end
  end
end

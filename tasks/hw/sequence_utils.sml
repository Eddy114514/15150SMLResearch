(* @solution *)
structure Utils :> UTILS =
struct
  (* collect: ('a * 'a -> order) -> 'a Seq.t -> 'a Seq.t Seq.t
   * REQUIRES:
   *    cmp is "well-behaved"
   *    cmp is total
   *    cmp has O(1) work/span
   * ENSURES: collect cmp S ==> C where
   *    Every element in S appears in some sequence of C
   *    If you sum the lengths of the sequences in C, you get the length of S
   *    Elements in each sequence in C are cmp-EQUAL
   *    Elements in earlier sequences in C are cmp-LESS than elements in
   *      later sequences in C
   *    No sequence in C is empty
   *    collect cmp S has O(|S|log|S|) work
   *    collect cmp S has O(log^2|S|) span
   *)



fun collect cmp S =
    let
      val front = Seq.sort cmp S (* Work:O(|S|log|S|) Span: O(log^2|S|) *)
      val enum = Seq.enum front  (* Work:O(|S|) Span: O(1) *)

      val length = Seq.length S  (* O(1) *)
      val toFront = fn x => length - x -1 (* O(1) *)

      val back = Seq.rev front (* Work: O(|S|) Span: O(1) *)

      (* O(1) *)
      fun revCmp (a, b) = 
          case cmp (a,b) of
            LESS => GREATER
          | EQUAL => EQUAL
          | GREATER => LESS

      fun generate (i, x) =
          let
            val first = Seq.search cmp x front (*Work: O(log|S|), Span(O(log|S|)) *)
            val last = Seq.search revCmp x back (*Work: O(log|S|), Span(O(log|S|)) *)
          in
            (*O(1)*)
            case (first, last) of 
                (NONE, _) => raise Fail "x in seq but can't search from front?"
              | (_, NONE) => raise Fail "x in seq but can't search from back?"
              | (SOME(first), SOME(last)) =>
              let
                val l = toFront(last) - first + 1
              in
                if i = first then (i, Seq.subseq front (first,l))
                         else (i, Seq.empty ())
              end   
          end
      val group = Seq.map generate enum (*Work: O(|S|log|S|), Span (O(log|S|))*)
      val cleanIndex = Seq.map (fn (_, x) => x) group (*Work: O(|S|), Span (O(1) *)
      val cleanEmpty = Seq.filter (fn x => not (Seq.null x)) cleanIndex  (*Work: O(|S|), Span (O(log|S|) *)
    in
      (*Have: O(|S|log|S|) Span: O(log^2|S|)*)
      cleanEmpty
    end

  (* unique: ('a * 'a -> order) -> 'a Seq.t -> 'a Seq.t
   * REQUIRES:
   *    cmp is "well-behaved" (it is reflexive, anti-symmetric, and transitive)
   *    cmp is total and has O(1) work and span
   * ENSURES: unique cmp S ==> T where
   *    Each element of S has an EQUAL element in T
   *    The elements of T are in strictly increasing order (this prevents
   *      the existence of duplicates)
   *    unique cmp S has O(|S| log |S|) work and O(log^2 |S|) span
   *)


  fun unique cmp S =
      let
        val groups = collect cmp S (*As previous, O(|S|log|S|) Span: O(log^2|S|)*)
        fun pick1 s = Seq.nth s 0 (* O(1) *)
      in
        if Seq.null S
        then S
        else Seq.map pick1 groups (*Work: O (|S|), Span: O(1) *)

        (*
          total: O(|S|log|S|) Span: O(log^2|S|)
        *)
      end

end
(* @manual hw_collect_int *)
(* @contract collect
 * Original: ('a * 'a -> order) -> 'a Seq.t -> 'a Seq.t Seq.t.
 * Int.compare is fixed. All input occurrences appear exactly once in nonempty
 * homogeneous groups, whose keys are strictly increasing. Group-internal
 * order is not imposed. Full content preservation is explicit in this study's
 * user requirements; the abbreviated starter wording alone omitted it.
 *)
functor ManualContract (Helpers : sig end) = struct
  type input = int Seq.t
  type output = int Seq.t Seq.t
  fun requires (_ : input) = true
  fun ensures (xs : input) (groups : output) = SeqSpec.collect Int.compare xs groups
end
(* @manual hw_collect_key *)
(* @contract collect
 * Original: ('a * 'a -> order) -> 'a Seq.t -> 'a Seq.t Seq.t.
 * Compare (key,id) by key. Preserve complete pair occurrences, grouping by
 * equivalence class and ordering the groups. Equal-key members may be reordered.
 *)
functor ManualContract (Helpers : sig end) = struct
  type input = (int * int) Seq.t
  type output = (int * int) Seq.t Seq.t
  fun requires (_ : input) = true
  fun ensures (xs : input) (groups : output) =
    SeqSpec.collect OrderSpec.keyCompare xs groups
end
(* @manual hw_unique_int *)
(* @contract unique
 * Original: ('a * 'a -> order) -> 'a Seq.t -> 'a Seq.t.
 * Int.compare is fixed. Output classes exactly cover input classes, with no
 * extra class or repeated class, in strictly increasing order. No particular
 * representative is forced; in this int instance equivalence is equality.
 *)
functor ManualContract (Helpers : sig end) = struct
  type input = int Seq.t
  type output = int Seq.t
  fun requires (_ : input) = true
  fun ensures (xs : input) (ys : output) = SeqSpec.unique Int.compare xs ys
end

(* @solution *)
(* This is the unchanged original functor. The runtime bridge in
 * support/tracker/Source.sml instantiates it through support.cm,
 * which loads the original HWANS file at top level. *)
functor MkTracker (Utils: UTILS) :> TRACKER =
struct

  (* you may assume this is a refsol for utils *)
  val unique = Utils.unique

  type mascot = int
  type chat = mascot Seq.t
  (* Don't forget to comment your tracker datatype! *)
  type tracker = chat Seq.t

  (* empty: int -> tracker
   * REQUIRES:
   *    n >= 0
   * ENSURES:
   *    empty n reflects that there are no group chats created and a mascot
   *      index is from 0 to n-1. This representation should support all
   *      calls to addChat and query
   *)
  fun empty (n : int) : tracker = Seq.tabulate (fn x => Seq.singleton x) n (*Work O(n), Span O(1). Since input f is constant*)

  (* addChat: tracker -> chat -> tracker
   * REQUIRES:
   *    Every member of the new chat has an index in 0 to n-1
   *    The chat has no duplicates
   *    T can be produced through calls to empty and addChat
   * ENSURES:
   *    addChat T C represents both C and the chats in T while maintaining the
   *      necessary invariants to give the right answer under future calls
   *      to addChat and query.
   *    O(|C| n log n) work and O(log^2 n) span.
   *)
  fun addChat (T : tracker) (C : chat) : tracker = 
  let
    fun newR x = 
      let
        val fromT = Seq.nth T x (* O(1) *)
        val new = Seq.append (fromT, C) (* Work: O(n + |C|), Span: O(1)*)
      in
        (x, Utils.unique Int.compare new) (* O(|n|log|n|) Span: O(log^2(n)) *)
      end
    val U = Seq.map newR C (*Work: O(|C| |n|log|n|) Span: O(log^2(n)) *)
  in
    Seq.inject (T, U) (* Work: O(n) Span: O(1) *) 

    (*
      In total: Work: O(|C| |n|log|n|) Span: O(log^2(n)) 
    *)
  end


  (* query: tracker -> mascot -> int -> mascot Seq.t
   * REQUIRES:
   *    The mascot has an index from 0 to n-1
   *    The resolution is non-negative
   *    T can be produced through calls to empty and addChat
   * ENSURES: query T m r ==> A
   *    A contains every mascot from 0 to n − 1 such that there exists mascots
   *      s0, s1, . . . , sr where s0 = m and for all 0 ≤ i < r, si and
   *      s(i+1) share a chat or si = s(i+1)
   *    O(r n^2 log n) work and O(r * log^2 n) span
   *)
  fun query (T : tracker) (m : mascot) (r : int) : mascot Seq.t = 
    let
      fun signal front i  = 
        if i = r then front
        else
          let
            val get = Seq.map (fn x => Seq.nth T x) front (*Work: O(n), Span: O(1), as input f is constant*)
            val all = Seq.flatten get (*Work: O(n + sum T), in which the max is O(n^2), Span: O(log (n)) *)

            (* The length of all is at most n^2 *)

            val newFront = Utils.unique Int.compare all 
            (* Work O(|n^2|log|n^2|) Span: O(log^2(n^2)) ==> *)
            (* tightest: Work O(|n^2|log|n|) Span: O(log^2(n))*)
          in
            signal newFront (i+1)
          end
      in
        signal (Seq.singleton m) 0 (*Work O(r n^2 log n), Span O(r * log^2 n), as signal runs at most r times.*) 
      end
end

(* @manual hw_tracker *)
(* @contract tracker_query
 * query : tracker -> int -> int -> int Seq.t
 * REQUIRES: n >= 0; each chat contains distinct indices in 0..n-1;
 * the source has a valid index; resolution >= 0. The adapter constructs
 * the tracker only through empty and addChat, as required by the assignment.
 * ENSURES: The result contains exactly the mascots reachable from the source
 * in at most resolution shared-chat steps. Result order is not specified.
 *)
functor ManualContract (Helpers : sig end) = struct
  type input = int * int list list * int * int
  type output = int list

  fun requires (n,chats,source,resolution) =
    let
      fun validIndex x = 0 <= x andalso x < n
      fun validChat chat = List.all validIndex chat andalso
        List.all (fn x => List.length (List.filter (fn y => x = y) chat) = 1) chat
    in n >= 0 andalso validIndex source andalso resolution >= 0
       andalso List.all validChat chats
    end

  fun ensures input result =
    let val expected = TrackerModel.receivers input
    in Spec.subset (result,expected) andalso Spec.subset (expected,result) end
end

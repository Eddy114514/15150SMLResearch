(* @solution *)
(* findPartition :
 *  'e list ->
 *  ('e list -> ('l -> 'a) -> (unit -> 'a) -> 'a) ->
 *  ('e list -> ('r -> 'a) -> (unit -> 'a) -> 'a) ->
 *  ('l * 'r -> 'a) ->
 *  (unit -> 'a) ->
 *  'a
 * REQUIRES: pL and pR are CPS-total
 * ENSURES: findPartition A pL pR sc fc ==>
 *  sc (evL, evR) if there exists a partition (L, R) of A
 *  such that pL accepts L with evL and pR accepts R with evR.
 *  fc () otherwise.
 *)
fun findPartition
  ([] : 'e list)
  (pL : 'e list -> ('l -> 'a) -> (unit -> 'a) -> 'a)
  (pR : 'e list -> ('r -> 'a) -> (unit -> 'a) -> 'a)
  (sc : 'l * 'r -> 'a)
  (fc : unit -> 'a)
  : 'a = 
  pL [] (fn L => pR [] (fn R => sc (L, R))(fn () => fc ())) fc
  | findPartition (x::xs) pL pR sc fc = 
    let
      val newFC = fn () => findPartition xs pL (fn list => pR (x::list)) sc fc
    in
      findPartition xs (fn list => pL (x::list)) pR sc newFC
    end

(* @manual hw_find_partition *)
(* @contract hw_find_partition
 * findPartition : 'e list ->
 *   ('e list -> ('l -> 'a) -> (unit -> 'a) -> 'a) ->
 *   ('e list -> ('r -> 'a) -> (unit -> 'a) -> 'a) ->
 *   ('l * 'r -> 'a) -> (unit -> 'a) -> 'a
 * REQUIRES: The two predicates are CPS-total. The finite descriptions below
 * construct total predicates; their bounds are generation settings only.
 * ENSURES: SOME (leftEvidence,rightEvidence) for any accepted stable partition
 * of all input positions, or NONE exactly when no accepted partition exists.
 *)
functor ManualContract (Helpers : sig end) = struct
  type input = PartitionCase.input
  type output = PartitionCase.output
  fun requires (_ : input) = true
  fun ensures input result =
    let val candidates = PartitionModel.evidence input
    in case result of
         NONE => null candidates
       | SOME evidence => List.exists (fn expected => evidence = expected) candidates
    end
end

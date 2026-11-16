

(* updateClauseVar : var -> clause -> (unit -> 'a) -> (clause -> 'a) -> 'a
 * REQUIRES: true
 * ENSURES : updateClauseVar var clause sat update ==>
 *    - sat ()            if the assignment of var makes the clause satisfied
 *    - update clause'    otherwise, where clause' is clause with ~var removed
 *)
fun updateClauseVar
  (var : var)
  ([] : clause)
  (sat : unit -> 'a)
  (update : clause -> 'a)
  : 'a = 
  update []
  | updateClauseVar var (x::xs) sat update =
  if x = var then sat ()
  else
  let
    fun newUpdate list = if x = ~var then update list else update (x::list)
  in
    updateClauseVar var xs sat newUpdate
  end


(*
val sat = fn () => "sat";
val update = MakeString.int_list;
val sat1 = updateClauseVar 1 [1 , 2 , 3] sat update;
val not23 = updateClauseVar (~1) [1 , 2 , 3] sat update; 
val sat2 = updateClauseVar 1 [1 , 2 , 3 , ~1] sat update; 
val not23 = updateClauseVar 1 [~1 , 2 , 3 , ~1] sat update; 
val not23 =updateClauseVar (1) [~1 , ~2 , 3 , ~1] sat update; 
val empty =updateClauseVar 1 [] sat update;
*)
    

(* updateFormulaVar : var -> formula -> (formula -> 'a) -> 'a
 * REQUIRES: true
 * ENSURES : updateFormulaVar var formula k ==> k formula'
 * where formula' is the formula after assigning var
 *)
fun updateFormulaVar
  (var : var)
  ([] : formula)
  (k : formula -> 'a)
  : 'a = k []
  | updateFormulaVar var (clause::formula) k =
  let
    val sat = fn () => updateFormulaVar var formula k

    val update = fn list => updateFormulaVar var formula 
                            (fn gets => k (list :: gets))
  in
    updateClauseVar var clause sat update
  end 

(*
val k = MakeString.list MakeString.int_list;
val get1 = updateFormulaVar 1 [[1 , 2 , 3] , [1 , 4 , 5] , [1 , 6 , 7]] k;
val get2 = updateFormulaVar (~1) [[1 , 2 , 3] , [1 , 4 , 5] , [1 , 6 , 7]] k;
val get21 = updateFormulaVar (~1) [[~1 , 2 , 3] , [~1 , 4 , 5] , [1 , 6 , 7]] k;
val get3 = updateFormulaVar 1 [[1 , 2 , 3] , [1 , 4 , 5] , [~1]] k;
val get4 = updateFormulaVar 1 [] k;
val get5 = updateFormulaVar 1 [[]] k;
*)

(* unitProp : formula -> (assignment * formula -> 'a) -> (unit -> 'a) -> 'a
 * REQUIRES: true
 * ENSURES : unitProp formula update unsat ==>
 *    - unsat ()                if through unit propagation, we can derive
 *                              the empty clause
 *    - update (asgn,formula')  otherwise, where asgn is the variables assigned
 *                              through unit propagation and formula' is
 *                              formula with no more singleton clauses and no
 *                              empty clauses
 *)
fun unitProp
  (formula : formula)
  (update : assignment * formula -> 'a)
  (unsat : unit -> 'a)
  : 'a =
  let
    fun signletionSC var =
      let
        val k = fn newF => unitProp newF (fn (list, f) => update (var::list,f)) unsat
      in
        updateFormulaVar var formula k
      end 
    val singletonFC = fn () => update ([],formula)
    val EmptyFc = fn () => find isSingleton formula signletionSC singletonFC
  in
    find isEmpty formula unsat EmptyFc
  end

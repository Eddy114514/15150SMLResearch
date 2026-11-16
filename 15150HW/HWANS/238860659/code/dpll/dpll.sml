
(* dpll : formula -> (assignment -> 'a) -> (unit -> 'a) -> 'a
 * REQUIRES: true
 * ENSURES : dpll formula sat unsat ==>
 *    - unsat ()     if there is no satisfying assignment to formula
 *    - sat asgn     if there is a satisfying assignment to formula, asgn
 *)
fun dpll
  ([] : formula)
  (sat : assignment -> 'a)
  (unsat : unit -> 'a)
  : 'a = sat []
  | dpll cnf sat unsat = 
  let
    fun update (asgn, formula) =
    case formula of 
            [] => sat asgn
     | (var::clause)::f =>  
        let
          val newSat = fn list => append (list,asgn) sat
          val kneg = fn newF => dpll newF (fn list => newSat ((~var)::list)) unsat
          val newUnset = fn () => updateFormulaVar (~var) formula kneg
          val k = fn newF => dpll newF (fn list => newSat (var::list)) newUnset
          fun pick1 () = updateFormulaVar var formula k
        in
          find isEmpty formula unsat pick1
        end
      | _ => unsat ()
    in
      unitProp cnf update unsat
    end 

val get1 = dpll [[1,~2],[2],[3,4]] SOME (fn ()=> NONE)









(*

let
    
    fun update (asgn, []) = sat asgn
      | update (asgn, formula) = 
      let
        fun pick1 =
          let 
            val (var::clause)::f = formula 
            val kneg = fn newF => dpll newF (fn list => sat (var::list)) unsat
            val k = fn newF => dpll newF (fn list => sat (var::list)) (updateFormulaVar (~var) formula kneg)
          in 
            updateFormulaVar var formula k
          end 
      in
        find isEmpty formula unsat pick1
      end
      
  in
    unitProp cnf update unsat
  end
*)
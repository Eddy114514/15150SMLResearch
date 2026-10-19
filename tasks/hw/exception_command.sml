(* @solution *)
datatype aexp =
  AConst of int
| Variable of string
| Add of aexp * aexp
| Sub of aexp * aexp
| Mult of aexp * aexp

datatype bexp =
  BConst of bool
| Equals of aexp * aexp
| NotEquals of aexp * aexp
| LessThan of aexp * aexp
| LessThanEqual of aexp * aexp
| GreaterThan of aexp * aexp
| GreaterThanEqual of aexp * aexp
| Not of bexp
| And of bexp * bexp
| Or of bexp * bexp

datatype command =
  Assign of string * aexp
| If of bexp * command list * command list
| Loop of command list
| Break
| Continue
| Return of aexp

type program = command list

type environment = (string * int) list

exception UnitializedVariable of string

(* set: string -> int -> environment -> environment
 * REQUIRES: true
 * ENSURES: set x n env ~= env' where
 *                          - If x was in env, its value is updated to n
 *                          - If x was not in env, it is created with the
 *                            initial value n
 *)
fun set (x : string) (v : int) : environment -> environment = fn
  [] => [(x, v)]
| (y, w)::es => if y = x then (x, v)::es else (y, w):: set x v es

(* get: environment -> string -> int
 * REQUIRES: true
 * ENSURES: get env x ~= n if x is in env, where n is the value of x.
 *                       raises UninitalizedVariable x otherwise
 *)
fun get (env : environment) (x : string) : int =
  case List.find (fn (y, _) => x = y) env of
    NONE => raise UnitializedVariable x
  | SOME (_, v) => v

val emptyEnvironment = []

(* evalAexp: environment -> aexp -> int
 * REQUIRES: every variable used in ae is initialized in env
 * ENSURES: evalAexp env ae ~= the result of evaluating the arithmetic
 *                             expression ae with the environment env
 *)
fun evalAexp (env : environment) :  aexp -> int = fn
    AConst n => n
  | Variable x => get env x
  | Add (e1, e2) => evalAexp env e1 + evalAexp env e2
  | Sub (e1, e2) => evalAexp env e1 - evalAexp env e2
  | Mult (e1, e2) => evalAexp env e1 * evalAexp env e2

(* evalBexp: environment -> bexp -> bool
 * REQUIRES: every variable used in be is initialized in env
 * ENSURES: evalAexp env be ~= the result of evaluating the boolean
 *                             expression be with the environment env
 *)
fun evalBexp (env : environment) : bexp -> bool = fn
    BConst b => b
  | Equals (e1, e2) => evalAexp env e1 = evalAexp env e2
  | NotEquals (e1, e2) => evalAexp env e1 <> evalAexp env e2
  | LessThan (e1, e2) => evalAexp env e1 < evalAexp env e2
  | LessThanEqual (e1, e2) => evalAexp env e1 <= evalAexp env e2
  | GreaterThan (e1, e2) => evalAexp env e1 > evalAexp env e2
  | GreaterThanEqual (e1, e2) => evalAexp env e1 >= evalAexp env e2
  | Not e => not (evalBexp env e)
  | And (e1, e2) => evalBexp env e1 andalso evalBexp env e2
  | Or (e1, e2) => evalBexp env e1 orelse evalBexp env e2

exception BreakExn of environment
exception ContinueExn of environment
exception ReturnExn of int

(* runCommand: environment -> command -> environment
 * REQUIRES: runCommand will only be invoked during the interpretation of a
 *           well-formed Cnot program
 * ENSURES: runCommand env cmd either
 *            - Evaluates to env', where env' is the result of updating env
 *              according to cmd
 *            - Raises an exception as specified in the handout
 *)
fun runCommand (env : environment) : command -> environment = 
  fn 
    Assign(x, e) => set x (evalAexp env e) env
  | If(bexp, cmds1, cmds2) => 
      if (evalBexp env bexp) then (runCommands env cmds1) else (runCommands env cmds2)
  | Loop(cmds) =>let
                    fun repeat env' = repeat
                        (runCommands env' cmds) handle
                                  BreakExn(brkEnv) => brkEnv
                                | ContinueExn(conEnv) => repeat conEnv
                 in
                    repeat env
                 end
  | Break => raise BreakExn(env)
  | Continue => raise ContinueExn(env)
  | Return(aexp) => raise ReturnExn(evalAexp env aexp)

and runCommands env cmds = foldl (fn (c, e) => runCommand e c) env cmds


(* @manual hw_exception_command *)
(* @contract runCommand
 * runCommand : environment -> command -> environment
 * Study slice: constant Assign/Return, Break/Continue, boolean If, counted Loop.
 * Bindings are prior assignments. Uncaught Break/Continue describe statements
 * in an enclosing loop body; complete programs and parsing are not checked.
 * REQUIRES: Loop counts are nonnegative. A loop body cannot assign its counter
 * or use it as a nested loop counter. Every nested action is valid as well.
 * ENSURES: The outcome tag and all visible bindings (or returned integer)
 * match the independent finite model. Loops initialize their counter to zero
 * and increment before each body, so Continue cannot prevent progress.
 *)
functor ManualContract (Helpers : sig end) = struct
  type input = CommandCase.bindings * CommandCase.action
  type output = CommandCase.outcome
  open CommandCase

  fun writes name (Assign (key,_)) = name = key
    | writes name (If (_,yes,no)) = List.exists (writes name) (yes @ no)
    | writes name (Loop (counter,_,body)) =
        name = counter orelse List.exists (writes name) body
    | writes _ _ = false

  fun valid (If (_,yes,no)) = List.all valid (yes @ no)
    | valid (Loop (counter,count,body)) =
        count >= 0 andalso not (List.exists (writes counter) body)
        andalso List.all valid body
    | valid _ = true

  (* This model appends assignment history and uses data for control signals.
   * It does not call Target or reproduce the solution's exception handlers. *)
  fun expected bindings action =
    case action of
      Assign binding => Completed (bindings @ [binding])
    | Break => Broke bindings
    | Continue => Continued bindings
    | Return value => Returned value
    | If (condition,yes,no) => commands bindings (if condition then yes else no)
    | Loop (counter,count,body) =>
        let
          fun repeat remaining history =
            if remaining = 0 then Completed history
            else
              case commands (history @ [(counter,count-remaining+1)]) body of
                Completed next => repeat (remaining-1) next
              | Continued next => repeat (remaining-1) next
              | Broke next => Completed next
              | Returned value => Returned value
        in repeat count (bindings @ [(counter,0)]) end
  and commands bindings [] = Completed bindings
    | commands bindings (action::rest) =
        case expected bindings action of
          Completed next => commands next rest
        | signal => signal

  fun matches bindings actual = let
    (* get observes the first binding, independent of shadowed representation.
     * Input descriptions are assignment histories, so their latest value wins. *)
    fun lookup entries name = Option.map (fn (_,value) => value)
      (List.find (fn (key,_) => key = name) entries)
    val names = List.map (fn (name,_) => name) (bindings @ actual)
  in
    List.all (fn name => lookup actual name = lookup (List.rev bindings) name) names
  end
  fun requires ((_,action) : input) = valid action
  fun ensures ((bindings,action) : input) (result : output) =
    case (expected bindings action,result) of
      (Completed history,Completed actual) => matches history actual
    | (Broke history,Broke actual) => matches history actual
    | (Continued history,Continued actual) => matches history actual
    | (Returned value,Returned actual) => actual = value
    | _ => false
end

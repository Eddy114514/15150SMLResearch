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
 * Functional reference for a declared finite subset, not the full contract.
 * The original REQUIRES concerns an enclosing well-formed program, including
 * eventual Return; that program is absent from this observation interface.
 * Reference domain: constant Assign/Return, Break/Continue, boolean If, counted
 * Loop with a body that never assigns or reuses that loop counter, recursively.
 * Negative counts execute zero iterations. These restrictions are sufficient
 * for this reference, not equivalent to the original well-formedness predicate.
 * Bindings are assignment history. Break/Continue are signals for an enclosing
 * loop. Compare outcome tags and visible bindings (or returned integer).
 * Loops start counter=0 and increment before each body, so Continue progresses.
 *)
functor ManualContract (Helpers : sig end) = struct
  type input = CommandCase.bindings * CommandCase.action
  type output = CommandCase.outcome
  open CommandCase

  fun requires ((_,action) : input) = CommandModel.valid action
  fun ensures ((bindings,action) : input) (result : output) =
    case (CommandModel.expected bindings action,result) of
      (Completed history,Completed actual) => CommandModel.matches history actual
    | (Broke history,Broke actual) => CommandModel.matches history actual
    | (Continued history,Continued actual) => CommandModel.matches history actual
    | (Returned value,Returned actual) => actual = value
    | _ => false
end

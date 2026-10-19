(* Sampling bounds: depth 2, up to 3 commands per branch/body, loop count 0..4.
 * User assignments use x/y/z; loop counters use distinct names by depth.
 * The contract checks counter protection, not these sampling budgets. *)
structure CommandData = struct
  structure G = QCheck.Gen
  val name = G.select #["x","y","z"]
  val value = G.range (~20,20)
  val bindings = G.vector List.tabulate (G.range (0,10),G.zip (name,value))
  val atomic = G.choose #[
    G.map CommandCase.Assign (G.zip (name,value)),
    G.lift CommandCase.Break, G.lift CommandCase.Continue,
    G.map CommandCase.Return value]
  fun atDepth 0 = atomic
    | atDepth depth =
        let val commands = G.vector List.tabulate
              (G.range (0,3),atDepth (depth-1))
            val counter = "__pbt_loop_" ^ Int.toString depth
        in G.choose #[atomic,
             G.map CommandCase.If (G.zip3 (G.flip,commands,commands)),
             G.map (fn (count,body) => CommandCase.Loop (counter,count,body))
               (G.zip (G.range (0,4),commands))]
        end
  val action = atDepth 2
  val genInput = G.zip (bindings,action)
  val outer = "__pbt_loop_2"
  val inner = "__pbt_loop_1"
  val edges = [
    (* Atomic behavior, environment updates, and repeated assignment history. *)
    ([],CommandCase.Assign ("x",1)),
    ([("x",1),("y",2)],CommandCase.Assign ("x",3)),
    ([("x",1),("y",2)],CommandCase.Assign ("z",3)),
    ([("x",1),("x",2)],CommandCase.Assign ("y",4)),
    ([],CommandCase.Break), ([("x",1),("y",2)],CommandCase.Break),
    ([],CommandCase.Continue), ([("x",1),("y",2)],CommandCase.Continue),
    ([],CommandCase.Return 0), ([("x",1)],CommandCase.Return ~3),
    ([("x",valOf Int.minInt)],CommandCase.Return (valOf Int.maxInt)),
    (* Both branches, skipped returns, command order, and exception propagation. *)
    ([],CommandCase.If (true,[CommandCase.Assign ("x",1)],[CommandCase.Return 99])),
    ([],CommandCase.If (false,[CommandCase.Return 99],[CommandCase.Assign ("x",2)])),
    ([("x",0)],CommandCase.If (true,
      [CommandCase.Assign ("x",1),CommandCase.Assign ("x",2)],[])),
    ([("x",3)],CommandCase.If (true,[],[CommandCase.Return 99])),
    ([],CommandCase.If (true,
      [CommandCase.Assign ("x",1),CommandCase.Break,CommandCase.Assign ("x",99)],[])),
    ([],CommandCase.If (false,[],
      [CommandCase.Assign ("x",1),CommandCase.Continue,CommandCase.Assign ("x",99)])),
    ([],CommandCase.If (true,[CommandCase.Return 7,CommandCase.Return 99],[])),
    ([],CommandCase.If (false,[CommandCase.Return 7],[CommandCase.Return 9])),
    ([],CommandCase.If (false,[],
      [CommandCase.If (true,[CommandCase.Assign ("y",4)],[CommandCase.Return 99])])),
    (* The counter exposes the number of iterations, including early exits. *)
    ([],CommandCase.Loop (outer,0,[CommandCase.Return 99])),
    ([(outer,99),("x",2)],CommandCase.Loop (outer,0,[CommandCase.Return 99])),
    ([],CommandCase.Loop (outer,3,[])),
    ([("x",0)],CommandCase.Loop (outer,3,
      [CommandCase.Assign ("x",7),CommandCase.Assign ("y",9)])),
    ([],CommandCase.Loop (outer,4,
      [CommandCase.Assign ("x",2),CommandCase.Break,CommandCase.Assign ("x",99)])),
    ([],CommandCase.Loop (outer,4,
      [CommandCase.Assign ("x",2),CommandCase.Continue,CommandCase.Assign ("x",99)])),
    ([],CommandCase.Loop (outer,4,[CommandCase.Return 7,CommandCase.Return 99])),
    ([],CommandCase.Loop (outer,3,
      [CommandCase.If (false,[CommandCase.Break],[CommandCase.Assign ("z",5)])])),
    (* Inner Break/Continue stay local; Return crosses both loops. *)
    ([],CommandCase.Loop (outer,3,
      [CommandCase.Loop (inner,3,[CommandCase.Assign ("x",7),CommandCase.Break]),
       CommandCase.Assign ("y",8)])),
    ([],CommandCase.Loop (outer,3,
      [CommandCase.Loop (inner,2,
        [CommandCase.Assign ("x",7),CommandCase.Continue,CommandCase.Assign ("x",99)]),
       CommandCase.Assign ("y",8)])),
    ([],CommandCase.Loop (outer,3,
      [CommandCase.Loop (inner,2,[CommandCase.Return 7]),CommandCase.Return 99])),
    (* Loop completion resumes the surrounding command sequence. *)
    ([],CommandCase.If (true,
      [CommandCase.Loop (outer,3,[CommandCase.Continue]),CommandCase.Assign ("z",9)],[])),
    ([],CommandCase.If (true,
      [CommandCase.Loop (outer,2,[]),CommandCase.Loop (outer,1,[])],[]))]
  fun showBindings xs = Runner.list
    (fn (name,value) => Runner.object [("name",Runner.quote name),("value",Runner.int value)]) xs
  fun showAction (CommandCase.Assign (name,value)) = Runner.object
        [("tag",Runner.quote "Assign"),("name",Runner.quote name),("value",Runner.int value)]
    | showAction CommandCase.Break = Runner.object [("tag",Runner.quote "Break")]
    | showAction CommandCase.Continue = Runner.object [("tag",Runner.quote "Continue")]
    | showAction (CommandCase.Return value) = Runner.object
        [("tag",Runner.quote "Return"),("value",Runner.int value)]
    | showAction (CommandCase.If (condition,yes,no)) = Runner.object
        [("tag",Runner.quote "If"),("condition",Runner.bool condition),
         ("then",Runner.list showAction yes),("else",Runner.list showAction no)]
    | showAction (CommandCase.Loop (counter,count,body)) = Runner.object
        [("tag",Runner.quote "Loop"),("counter",Runner.quote counter),
         ("count",Runner.int count),("body",Runner.list showAction body)]
  fun showInput (bindings,action) = Runner.object
    [("bindings",showBindings bindings),("action",showAction action)]
  fun environment tag bindings = Runner.object
    [("tag",Runner.quote tag),("bindings",showBindings bindings)]
  fun showOutput (CommandCase.Completed bindings) = environment "Completed" bindings
    | showOutput (CommandCase.Broke bindings) = environment "BreakExn" bindings
    | showOutput (CommandCase.Continued bindings) = environment "ContinueExn" bindings
    | showOutput (CommandCase.Returned value) = Runner.object
        [("tag",Runner.quote "ReturnExn"),("value",Runner.int value)]
end

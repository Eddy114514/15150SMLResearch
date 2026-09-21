(* QCheck executes the property and owns iteration, valid counts and failures.
 * Its empty shrinker still confirms a failure by running that input again. *)
structure Runner = struct
  val prefix = "@@SMLPBT@@"
  fun int n = String.translate (fn #"~" => "-" | c => str c) (Int.toString n)
  fun bool b = if b then "true" else "false"
  fun quote s = "\"" ^ String.translate
    (fn #"\"" => "\\\"" | #"\\" => "\\\\" | #"\n" => "\\n"
      | #"\r" => "\\r" | #"\t" => "\\t"
      | c => if Char.ord c < 32 then
          "\\u00" ^ StringCvt.padLeft #"0" 2 (Int.fmt StringCvt.HEX (Char.ord c))
        else str c) s ^ "\""
  fun list f xs = "[" ^ String.concatWith "," (List.map f xs) ^ "]"
  fun pair (x, xs) = "[" ^ int x ^ "," ^ list int xs ^ "]"
  fun listIntPair (xs, x) = "[" ^ list int xs ^ "," ^ int x ^ "]"
  fun field (k, v) = quote k ^ ":" ^ v
  fun object fields = "{" ^ String.concatWith "," (List.map field fields) ^ "}"
  fun option f NONE = object [("tag", quote "NONE")]
    | option f (SOME x) = object [("tag", quote "SOME"), ("value", f x)]
  fun emit fields = (print (prefix ^ object fields ^ "\n"); TextIO.flushOut TextIO.stdOut)
  fun exnText e = General.exnName e ^ ": " ^ General.exnMessage e
  fun writeInputs (path, showInput, inputs) = let
    val stream = TextIO.openOut path
  in
    TextIO.output (stream, "[\n" ^ String.concatWith ",\n"
      (List.map (fn x => "  " ^ showInput x) inputs) ^ "\n]\n");
    TextIO.closeOut stream
  end

  fun run {requires, ensures, target, showInput, showOutput,
           inputs, validTarget} = let
    exception RequiresError
    val stop = ref false
    val attempted = ref 0
    val discarded = ref 0
    val passed = ref 0
    val targetCalls = ref 0
    (* A copy of the last callback's count, used only if requires exits before
     * QCheck can call status/finish. Normal completion uses QCheck's stats. *)
    val previousCount = ref 0
    val output = ref NONE
    val firstError = ref NONE
    fun remember stage x result error =
      case !firstError of NONE => firstError := SOME (stage, x, result, error)
        | SOME _ => ()
    fun condition x =
      (output := NONE;
       requires x handle e => (remember "requires" x NONE e; raise RequiresError))
    fun body x = let
      val _ = targetCalls := !targetCalls + 1
      val y = target x handle e => (remember "target" x NONE e; raise e)
      val _ = output := SOME y
    in ensures x y handle e => (remember "ensures" x (SOME y) e; raise e) end
    val property = QCheck.implies (condition, QCheck.pred body)
    fun report count status stage input result error = emit
      [("status", quote status), ("stage", quote stage),
       ("attempted", int (!attempted)), ("accepted", int count),
       ("discarded", int (!discarded)), ("passed", int (!passed)),
       ("errored", if Option.isSome error then "1" else "0"),
       ("target_calls", int (!targetCalls)),
       ("counterexample_input", case input of NONE => "null" | SOME x => showInput x),
       ("counterexample_output", case result of NONE => "null" | SOME y => showOutput y),
       ("exception", case error of NONE => "null" | SOME e => quote (exnText e))]
    fun reportError count (stage, x, result, error) =
      report count (if stage = "target" then "target_exception" else "predicate_error")
        stage (SOME x) result (SOME error)
    fun finish failures ({count, ...} : QCheck.stats) =
      case !firstError of
        SOME error => reportError count error
      | NONE => case failures of
          x :: _ => report count "counterexample" "ensures" (SOME x) (!output) NONE
        | [] => if validTarget > 0 andalso count >= validTarget then
            report count "passed_sampled_tests" "ensures" NONE NONE NONE
          else report count "insufficient_valid_inputs" "requires" NONE NONE NONE
    fun onStatus (_, result, {count, ...} : QCheck.stats) =
      (attempted := !attempted + 1;
       previousCount := count;
       case result of
         NONE => discarded := !discarded + 1
       | SOME true => passed := !passed + 1
       | SOME false => stop := true)
    fun next xs = if !stop then NONE else List.getItem xs
    val _ = QCheck.Settings.set (QCheck.Settings.gen_target, SOME validTarget)
  in
    QCheck.cpsCheck (fn _ => []) QCheck.stats (next, SOME showInput)
      property onStatus finish inputs
    handle RequiresError =>
      (attempted := !attempted + 1;
       reportError (!previousCount) (valOf (!firstError)))
  end

end

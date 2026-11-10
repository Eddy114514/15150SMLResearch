(* Trusted labelled checks are independent of a candidate's input filter.
 * Each thunk reconstructs its input/output for each individual observation. *)
structure SemanticEvaluation = struct
  type failure = {stage : string, label : string, expected : bool,
                  actual : bool option, input : string option,
                  output : string option}

  fun run {requires, ensures, requiresCases, ensuresCases, showInput, showOutput} = let
    val firstFailure : failure option ref = ref NONE
    val failed = ref 0
    val errors = ref 0
    val firstException : string option ref = ref NONE
    val requiresChecked = ref 0
    val ensuresChecked = ref 0
    fun count label cases = List.length (List.filter (fn (_, _, b) => b = label) cases)
    val valid = count true requiresCases
    val invalid = count false requiresCases
    val positive = count true ensuresCases
    val negative = count false ensuresCases
    fun remember failure =
      (failed := !failed + 1;
       case !firstFailure of NONE => firstFailure := SOME failure | SOME _ => ())
    fun check stage label expected action =
      (let val (actual, input, output) = action ()
       in if actual = expected then () else remember
         {stage=stage, label=label, expected=expected, actual=SOME actual,
          input=SOME input, output=output}
       end handle e => let val error = Runner.exnText e in
         errors := !errors + 1;
         (case !firstException of NONE => firstException := SOME error | SOME _ => ());
         remember {stage=stage, label=label, expected=expected, actual=NONE,
           input=NONE, output=NONE}
       end)
    fun checkRequires (label, make, expected) =
      check "requires" label expected (fn () => let
        val input = make ()
        val shown = showInput input
      in (requires input, shown, NONE) end)
    fun checkEnsures (label, make, expected) =
      check "ensures" label expected (fn () => let
        val (input, output) = make ()
        val shownInput = showInput input
        val shownOutput = showOutput output
      in (ensures input output, shownInput, SOME shownOutput) end)
    val _ = List.app (fn item =>
      (requiresChecked := !requiresChecked + 1; checkRequires item)) requiresCases
    (* Never filter these fixed output checks through the supplied requires. *)
    val _ = List.app (fn item =>
      (ensuresChecked := !ensuresChecked + 1; checkEnsures item)) ensuresCases
    val status = if !errors > 0 then "predicate_error"
      else if !failed > 0 then "semantic_counterexample" else "passed_semantic_checks"
    fun nullable f value = case value of NONE => "null" | SOME x => f x
    val details = case !firstFailure of NONE =>
        [("stage", Runner.quote "semantic"), ("counterexample_label", "null"),
         ("counterexample_input", "null"), ("counterexample_output", "null"),
         ("expected", "null"), ("actual", "null")]
      | SOME {stage, label, expected, actual, input, output, ...} =>
        [("stage", Runner.quote stage), ("counterexample_label", Runner.quote label),
         ("counterexample_input", nullable (fn x => x) input),
         ("counterexample_output", nullable (fn x => x) output),
         ("expected", Runner.bool expected), ("actual", nullable Runner.bool actual)]
  in Runner.emit
    ([("status", Runner.quote status),
      ("requires_valid", Runner.int valid), ("requires_invalid", Runner.int invalid),
      ("ensures_positive", Runner.int positive), ("ensures_negative", Runner.int negative),
      ("requires_checked", Runner.int (!requiresChecked)),
      ("ensures_checked", Runner.int (!ensuresChecked)),
      ("failed_checks", Runner.int (!failed)), ("errored", Runner.int (!errors)),
      ("exception", nullable Runner.quote (!firstException))] @ details)
  end
end

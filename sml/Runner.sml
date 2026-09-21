(* Evaluate each sample once before QCheck.pred can hide its exceptions.
 * QCheck.implies/test classify the resulting precondition and postcondition. *)
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
  fun field (k, v) = quote k ^ ":" ^ v
  fun object fields = "{" ^ String.concatWith "," (List.map field fields) ^ "}"
  fun emit fields = (print (prefix ^ object fields ^ "\n"); TextIO.flushOut TextIO.stdOut)
  fun exnText e = General.exnName e ^ ": " ^ General.exnMessage e
  fun numbers line = List.map (valOf o Int.fromString)
    (String.tokens (fn c => not (Char.isDigit c orelse c = #"-" orelse c = #"~")) line)
  fun readInt s = hd (numbers s)
  fun readList s = numbers s
  fun readPair s = let val values = numbers s in (hd values, tl values) end

  fun run {requires, ensures, target, readInput, showInput, showOutput,
           corpusPath, validTarget, maxAttempts} = let
    val attempted = ref 0
    val accepted = ref 0
    val discarded = ref 0
    val passed = ref 0
    val errored = ref 0
    val targetCalls = ref 0
    val stats = ref QCheck.stats
    val phase = ref "requires"
    val output = ref NONE
    fun finish status stage input message = emit
      [("status", quote status), ("stage", quote stage),
       ("attempted", int (!attempted)), ("accepted", int (!accepted)),
       ("discarded", int (!discarded)), ("passed", int (!passed)),
       ("errored", int (!errored)), ("target_calls", int (!targetCalls)),
       ("counterexample_input", case input of NONE => "null" | SOME x => showInput x),
       ("counterexample_output", case (input, !output) of (SOME _, SOME y) => showOutput y | _ => "null"),
       ("exception", case message of NONE => "null" | SOME s => quote s)]
    fun evaluate x =
      (let
         val precondition = requires x
         val postcondition = if precondition then let
           val _ = accepted := !accepted + 1
           val _ = phase := "target"
           val _ = targetCalls := !targetCalls + 1
           val y = target x
           val _ = output := SOME y
           val _ = phase := "ensures"
         in ensures x y end else true
       in SOME (precondition, postcondition) end
       handle e =>
         (errored := !errored + 1;
          finish (if !phase = "target" then "target_exception" else "predicate_error")
            (!phase) (SOME x) (SOME (exnText e));
          NONE))
    val stream = TextIO.openIn corpusPath
    val _ = TextIO.inputLine stream (* Opening bracket in our generated JSON. *)
    fun nextInput () = case TextIO.inputLine stream of
        NONE => NONE
      | SOME line => if String.isPrefix "]" line then NONE else SOME line
    fun loop () =
      if !accepted > 0 andalso !accepted >= validTarget then finish "passed_sampled_tests" "ensures" NONE NONE
      else if !attempted >= maxAttempts then finish "insufficient_valid_inputs" "requires" NONE NONE
      else case nextInput () of
        NONE => finish "insufficient_valid_inputs" "requires" NONE NONE
      | SOME line => let
          val x = readInput line
          val _ = attempted := !attempted + 1
          val _ = phase := "requires"
          val _ = output := NONE
        in case evaluate x of
          NONE => ()
        | SOME (precondition, postcondition) => let
            val property = QCheck.implies
              ((fn _ => precondition), QCheck.pred (fn _ => postcondition))
            val (result, nextStats) = QCheck.test property (x, !stats)
            val _ = stats := nextStats
          in case result of
              NONE => (discarded := !discarded + 1; loop ())
            | SOME true => (passed := !passed + 1; loop ())
            | SOME false => finish "counterexample" "ensures" (SOME x) NONE
          end
        end
  in loop (); TextIO.closeIn stream end

end

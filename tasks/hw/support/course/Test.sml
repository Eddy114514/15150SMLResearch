(* A simple testing framework for early in 150 *)
structure Test :> TEST =
struct

  val raiseExn = ref true
  fun shouldRaiseExn b = raiseExn := b

  fun fail s = if !raiseExn then raise Fail s else print s
  fun pass s = ()

  (* helper functions for generating the failure message
   * don't worry if you don't understand these... you will soon : )
   *)
  fun fail_eq_msg (name : string, expected : string, actual : string) =
    name
    ^ "!\nFirst argument:\n"
    ^ MakeString.indent expected
    ^ "\n\nSecond argument:\n"
    ^ MakeString.indent actual
    ^ "\n"

  fun test_eq (eq, toString) (name, expected, actual) =
    (if eq (expected, actual)
    then pass name
    else fail ( fail_eq_msg (name, toString expected, toString actual) )
    ) handle _ => fail (fail_eq_msg (name, toString expected, toString actual))
  fun test_property (prop, toString) (name, desc, value) =
    (if prop value
    then pass name
    else fail ( fail_eq_msg (name, desc, toString value) )
    ) handle _ => fail (fail_eq_msg (name, desc, toString value))


  fun general_eq (name, expected, actual) =
    (if expected = actual
    then pass name
    else fail name
    ) handle _ => fail name

  (* basic types *)
  val bool   = test_eq (op=, MakeString.bool)
  val int    = test_eq (op=, MakeString.int)
  val string = test_eq (op=, MakeString.string)
  val char   = test_eq (op=, MakeString.char)
  val order  = test_eq (op=, MakeString.order)


  (* lists -- exact equality *)
  fun list_eq (eq, toString) =
    test_eq (List.all eq o ListPair.zipEq, MakeString.list toString)
  val bool_list_eq   = list_eq (op=, MakeString.bool)
  val int_list_eq    = list_eq (op=, MakeString.int)
  val string_list_eq = list_eq (op=, MakeString.string)

  (* list lists -- exact equality *)
  fun list_list_eq (eq, toString) =
    test_eq ( List.all (List.all eq o ListPair.zipEq) o ListPair.zipEq
            , MakeString.list_list toString
            )
  val bool_list_list_eq   = list_list_eq (op=, MakeString.bool)
  val int_list_list_eq    = list_list_eq (op=, MakeString.int)
  val string_list_list_eq = list_list_eq (op=, MakeString.string)

  (* tuples *)
  fun pair ((eq1, eq2), toStrings) =
    test_eq ( fn ((a,b), (x,y)) => eq1 (a,x) andalso eq2 (b,y)
            , MakeString.pair toStrings
            )
  val int_int           = pair ((op=,op=), (MakeString.int, MakeString.int))
  val string_int        = pair ((op=,op=), (MakeString.string, MakeString.int))
  val int_string        = pair ((op=,op=), (MakeString.int, MakeString.string))
  val string_string     =
    pair ((op=,op=), (MakeString.string, MakeString.string))
  val int_list_int_list =
    pair ((op=,op=), (MakeString.int_list, MakeString.int_list))

  (* options *)
  fun option (eq, toString) =
    test_eq ( fn (SOME x,SOME y) => eq (x,y) | (NONE,NONE) => true | _ => false
            , MakeString.option toString
            )
  val int_option      = option (op=, MakeString.int)
  val string_option   = option (op=, MakeString.string)
  val int_list_option = option (op=, MakeString.int_list)
end

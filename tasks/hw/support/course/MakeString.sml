(* Utility Functions for turning various common types into strings *)
structure MakeString :> MAKE_STRING =
struct
  val isNewLine = fn #"\n" => true | _ => false
  fun indent s = "\t" ^ ((String.concatWith "\n\t" o String.tokens isNewLine) s)

  (* basic types *)
  val bool   = Bool.toString
  val int    = Int.toString
  val real   = Real.toString
  val string = fn s => "\"" ^ String.toString s ^ "\""
  val char   = fn c => "#" ^ (string o Char.toString) c
  val unit   = fn () => "()"
  val order  = fn LESS => "LESS" | EQUAL => "EQUAL" | GREATER => "GREATER"

  (* lists *)
  fun list f list = "[" ^ String.concatWith ", " (List.map f list) ^ "]"
  val bool_list    = list bool
  val int_list     = list int
  val string_list  = list string

  (* list lists *)
  fun list_list f ll =
    "[ " ^ String.concatWith "\n, " (List.map (list f) ll) ^ "\n]"
  val bool_list_list   = list_list bool
  val int_list_list    = list_list int
  val string_list_list = list_list string

  (* tuples *)
  fun pair (f,g) (a,b)  = "(" ^ f a ^ ", " ^ g b ^ ")"
  val int_int           = pair (int, int)
  val string_int        = pair (string, int)
  val int_string        = pair (int, string)
  val string_string     = pair (string, string)
  val int_list_int_list = pair (int_list, int_list)


  (* options *)
  fun option f        = fn NONE => "NONE" | SOME x => "SOME " ^ f x
  val int_option      = option int
  val string_option   = option string
  val int_list_option = option int_list
end

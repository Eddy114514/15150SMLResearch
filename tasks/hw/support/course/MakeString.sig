(* Utility Functions for turning various common types into strings *)
signature MAKE_STRING =
sig
  (*!
   * Indents the passed in string by one tab
   *)
  val indent : string -> string

  (* basic types *)
  val bool   : bool   -> string
  val int    : int    -> string
  val real   : real   -> string
  val string : string -> string
  val char   : char   -> string
  val unit   : unit   -> string
  val order  : order  -> string

  (* lists *)
  val list : ('a -> string) -> 'a list -> string
  val bool_list   : bool list   -> string
  val int_list    : int list    -> string
  val string_list : string list -> string

  (* list lists *)
  val list_list : ('a -> string) -> 'a list list -> string
  val bool_list_list   : bool list list   -> string
  val int_list_list    : int list list    -> string
  val string_list_list : string list list -> string

  (* tuples *)
  val pair : ('a -> string) * ('b -> string) -> 'a * 'b -> string
  val int_int : int * int -> string
  val string_int : string * int -> string
  val int_string : int * string -> string
  val string_string : string * string -> string
  val int_list_int_list : int list * int list -> string

  (* options *)
  val option : ('a -> string) -> 'a option -> string
  val int_option      : int option      -> string
  val string_option   : string option   -> string
  val int_list_option : int list option -> string
end

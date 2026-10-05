signature TEST =
sig

  (* Core outputs *)
  val shouldRaiseExn : bool -> unit
  val fail : string -> unit
  val pass : string -> unit

  (* General testers *)
  (*!
   * `test_eq (eq, toString) (name, expected, actual)` passes the test if
   *   the `expected` and `actual` values match according to `eq`, otherwise
   *   fails.
   *)
  val test_eq : (('a * 'a -> bool) * ('a -> string))
             -> string * 'a * 'a
             -> unit
  (*!
   * `test_property (p, toString) (name, desc, value)` passes the test if
   *   `value` has property `p`, fails otherwise.
   *)
  val test_property : (('a -> bool) * ('a -> string))
                   -> string * string * 'a
                   -> unit
  (*!
   * `general_eq (name, x, y)` passes the test if `x = y`, fails otherwise.
   *)
  val general_eq : string * ''a * ''a -> unit


  (* basic types *)
  val bool   : string * bool * bool -> unit
  val int    : string * int * int -> unit
  val string : string * string * string -> unit
  val char   : string * char * char -> unit
  val order  : string * order * order -> unit

  (* lists -- exact equality *)
  val list_eq : ('a * 'a -> bool) * ('a -> string)
             -> string * 'a list * 'a list
             -> unit
  val bool_list_eq   : (string * bool list * bool list) -> unit
  val int_list_eq    : (string * int list * int list) -> unit
  val string_list_eq : (string * string list * string list) -> unit

  (* list lists -- exact equality *)
  val list_list_eq : ('a * 'a -> bool) * ('a -> string)
                  -> string * 'a list list * 'a list list
                  -> unit
  val bool_list_list_eq   : (string * bool list list * bool list list) -> unit
  val int_list_list_eq    : (string * int list list * int list list) -> unit
  val string_list_list_eq : (string * string list list * string list list)
                         -> unit

  (* tuples *)
  val pair : (('a * 'a -> bool) * ('b * 'b -> bool))
             * (('a -> string) * ('b -> string))
          -> string * ('a * 'b) * ('a * 'b)
          -> unit
  val int_int : string * (int * int) * (int * int) -> unit
  val string_int : string * (string * int) * (string * int) -> unit
  val int_string : string * (int * string) * (int * string) -> unit
  val string_string : string * (string * string) * (string * string) -> unit
  val int_list_int_list : string
                          * (int list * int list)
                          * (int list * int list)
                       -> unit

  (* options *)
  val option : ('a * 'a -> bool) * ('a -> string)
            -> string * 'a option * 'a option
            -> unit
  val int_option      : string * int option * int option -> unit
  val string_option   : string * string option * string option -> unit
  val int_list_option : string * int list option * int list option -> unit

end

(* Fixed independent semantic labels; never included in model prompts.
 * Every thunk constructs fresh values for each predicate evaluation. *)
structure Evaluation = struct
  type input = RoseFoldCase.reducer * string * RoseFoldCase.rose
  type output = string * string

  val requiresCases : (string * (unit -> input) * bool) list = [
    ("valid-1", fn () => (RoseFoldCase.Append ",","z",RoseFoldCase.Rose (1,[RoseFoldCase.Rose (2,[]),RoseFoldCase.Rose (3,[])])), true),
    ("valid-2", fn () => (RoseFoldCase.Bracket,"z",RoseFoldCase.Rose (1,[RoseFoldCase.Rose (2,[])])), true),
    ("valid-3", fn () => (RoseFoldCase.Append ",","z",RoseFoldCase.Rose (1,[])), true)
  ]
  val ensuresCases : (string * (unit -> input * output) * bool) list = [
    ("ordered-preorder", fn () => ((RoseFoldCase.Append ",","z",RoseFoldCase.Rose (1,[RoseFoldCase.Rose (2,[]),RoseFoldCase.Rose (3,[])])), ("z,1,2,3","z,3,2,1")), true),
    ("nested-order", fn () => ((RoseFoldCase.Bracket,"z",RoseFoldCase.Rose (1,[RoseFoldCase.Rose (2,[])])), ("(2:(1:z))","(1:(2:z))")), true),
    ("same-fold-wrong", fn () => ((RoseFoldCase.Bracket,"z",RoseFoldCase.Rose (1,[RoseFoldCase.Rose (2,[])])), ("(1:(2:z))","(1:(2:z))")), false),
    ("lost-initial", fn () => ((RoseFoldCase.Append ",","z",RoseFoldCase.Rose (1,[])), (",1",",1")), false),
    ("singleton", fn () => ((RoseFoldCase.Append ",","z",RoseFoldCase.Rose (1,[])), ("z,1","z,1")), true)
  ]
end

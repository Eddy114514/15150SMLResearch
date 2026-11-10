(* Fixed independent semantic labels; never included in model prompts.
 * Every thunk constructs fresh values for each predicate evaluation. *)
structure Evaluation = struct
  type input = RegexCase.regex * string
  type output = bool

  val requiresCases : (string * (unit -> input) * bool) list = [
    ("valid-1", fn () => (RegexCase.Star (RegexCase.Char #"a"),""), true),
    ("valid-2", fn () => (RegexCase.Star (RegexCase.Char #"a"),"aaa"), true),
    ("valid-3", fn () => (RegexCase.Char #"a","ab"), true),
    ("valid-4", fn () => (RegexCase.Both (RegexCase.Char #"a",RegexCase.Char #"b"),"a"), true),
    ("nullable-star", fn () => (RegexCase.Star RegexCase.One,""), false)
  ]
  val ensuresCases : (string * (unit -> input * output) * bool) list = [
    ("empty-star", fn () => ((RegexCase.Star (RegexCase.Char #"a"),""), true), true),
    ("repeat", fn () => ((RegexCase.Star (RegexCase.Char #"a"),"aaa"), true), true),
    ("whole-string", fn () => ((RegexCase.Char #"a","ab"), false), true),
    ("intersection", fn () => ((RegexCase.Both (RegexCase.Char #"a",RegexCase.Char #"b"),"a"), false), true),
    ("prefix-is-not-full-match", fn () => ((RegexCase.Char #"a","ab"), true), false),
    ("false-rejection", fn () => ((RegexCase.Star (RegexCase.Char #"a"),"aaa"), false), false)
  ]
end

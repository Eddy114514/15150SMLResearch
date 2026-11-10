(* Fixed independent semantic labels; never included in model prompts.
 * Every thunk constructs fresh values for each predicate evaluation. *)
structure Evaluation = struct
  type input = RegexCase.regex * char list * bool list
  type output = bool

  val requiresCases : (string * (unit -> input) * bool) list = [
    ("valid-1", fn () => (RegexCase.Char #"a",[#"a",#"b"],[false,true,false]), true),
    ("valid-2", fn () => (RegexCase.Char #"a",[#"a"],[true,false]), true),
    ("valid-3", fn () => (RegexCase.One,[],[true]), true),
    ("unused-table-entries-are-allowed", fn () => (RegexCase.One,[],[true,false,true]), true),
    ("valid-4", fn () => (RegexCase.Zero,[],[true]), true),
    ("valid-5", fn () => (RegexCase.Both (RegexCase.One,RegexCase.Char #"a"),[#"a"],[true,true]), true),
    ("valid-6", fn () => (RegexCase.Both (RegexCase.Star (RegexCase.Char #"a"),RegexCase.Char #"a"),[#"a"],[false,true]), true),
    ("nullable-star", fn () => (RegexCase.Star RegexCase.One,[],[true]), false),
    ("short-table", fn () => (RegexCase.Char #"a",[#"a"],[true]), false)
  ]
  val ensuresCases : (string * (unit -> input * output) * bool) list = [
    ("continuation-after-prefix", fn () => ((RegexCase.Char #"a",[#"a",#"b"],[false,true,false]), true), true),
    ("continuation-rejects", fn () => ((RegexCase.Char #"a",[#"a"],[true,false]), false), true),
    ("epsilon", fn () => ((RegexCase.One,[],[true]), true), true),
    ("extra-table-values-do-not-restrict-domain", fn () => ((RegexCase.One,[],[true,false,true]), true), true),
    ("zero-language", fn () => ((RegexCase.Zero,[],[true]), false), true),
    ("both-needs-same-split", fn () => ((RegexCase.Both (RegexCase.One,RegexCase.Char #"a"),[#"a"],[true,true]), false), true),
    ("both-common-split", fn () => ((RegexCase.Both (RegexCase.Star (RegexCase.Char #"a"),RegexCase.Char #"a"),[#"a"],[false,true]), true), true),
    ("wrong-continuation-index", fn () => ((RegexCase.Char #"a",[#"a"],[true,false]), true), false),
    ("wrong-intersection", fn () => ((RegexCase.Both (RegexCase.One,RegexCase.Char #"a"),[#"a"],[true,true]), true), false),
    ("false-rejection", fn () => ((RegexCase.One,[],[true]), false), false)
  ]
end

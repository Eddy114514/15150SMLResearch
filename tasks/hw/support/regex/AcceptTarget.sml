structure TargetAdapter = struct
  fun regex RegexCase.Zero = Target.Zero
    | regex RegexCase.One = Target.One
    | regex (RegexCase.Char c) = Target.Char c
    | regex (RegexCase.Plus (a,b)) = Target.Plus (regex a,regex b)
    | regex (RegexCase.Times (a,b)) = Target.Times (regex a,regex b)
    | regex (RegexCase.Star a) = Target.Star (regex a)
    | regex (RegexCase.Both (a,b)) = Target.Both (regex a,regex b)
  fun run (r,text) = Target.accept (regex r) text
end

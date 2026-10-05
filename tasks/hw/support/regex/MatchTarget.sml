structure TargetAdapter = struct
  fun regex RegexCase.Zero = Target.Zero
    | regex RegexCase.One = Target.One
    | regex (RegexCase.Char c) = Target.Char c
    | regex (RegexCase.Plus (a,b)) = Target.Plus (regex a,regex b)
    | regex (RegexCase.Times (a,b)) = Target.Times (regex a,regex b)
    | regex (RegexCase.Star a) = Target.Star (regex a)
    | regex (RegexCase.Both (a,b)) = Target.Both (regex a,regex b)
  fun run (r,text,table) =
    let val n = List.length text
        (* Total even on a non-suffix; legal matcher continuations see suffixes. *)
        fun continuation rest =
          let val i = n - List.length rest
          in i >= 0 andalso i <= n andalso rest = List.drop (text,i)
             andalso List.nth (table,i) end
    in Target.match (regex r) text continuation end
end

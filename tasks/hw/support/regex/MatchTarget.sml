structure TargetAdapter = struct
  fun run (r,text,table) =
    let val n = List.length text
        (* Total even on a non-suffix; legal matcher continuations see suffixes. *)
        fun continuation rest =
          let val i = n - List.length rest
          in i >= 0 andalso i <= n andalso rest = List.drop (text,i)
             andalso List.nth (table,i) end
    in Target.match (RegexTarget.regex r) text continuation end
end

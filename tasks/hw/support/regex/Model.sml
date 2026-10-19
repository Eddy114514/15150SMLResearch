(* Independent finite-position language semantics. No call to Target.match.
 * Star computes a least fixed point on positions 0..|text|, so nullable
 * bodies terminate here even though the course matcher excludes them. *)
structure RegexModel = struct
  fun validMatch (r,text,table) = RegexCase.standard r andalso
    List.length table = List.length text + 1
  fun unique xs = List.foldl (fn (x,ys) => if Spec.member x ys then ys else x::ys) [] xs
  fun positions expression text =
    let val n = List.length text
        fun ends RegexCase.Zero _ = []
          | ends RegexCase.One i = [i]
          | ends (RegexCase.Char c) i =
              if i < n andalso List.nth (text,i) = c then [i+1] else []
          | ends (RegexCase.Plus (a,b)) i = unique (ends a i @ ends b i)
          | ends (RegexCase.Times (a,b)) i = unique (List.concat (List.map (ends b) (ends a i)))
          | ends (RegexCase.Both (a,b)) i =
              let val right = ends b i in List.filter (fn j => Spec.member j right) (ends a i) end
          | ends (RegexCase.Star a) i =
              let fun close [] seen = seen
                    | close (j::pending) seen =
                        if Spec.member j seen then close pending seen
                        else close (ends a j @ pending) (j::seen)
              in close [i] [] end
    in ends expression 0 end
  fun matches (r,text,table) =
    List.exists (fn i => List.nth (table,i)) (positions r text)
  fun accepts (r,text) = Spec.member (String.size text) (positions r (String.explode text))
end

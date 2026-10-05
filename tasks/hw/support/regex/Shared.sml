(* Lossless external regexp description, converted to Target.regexp at runtime. *)
structure RegexCase = struct
  datatype regex = Zero | One | Char of char | Plus of regex * regex
    | Times of regex * regex | Star of regex | Both of regex * regex
  fun nullable Zero = false
    | nullable One = true
    | nullable (Char _) = false
    | nullable (Plus (a,b)) = nullable a orelse nullable b
    | nullable (Times (a,b)) = nullable a andalso nullable b
    | nullable (Both (a,b)) = nullable a andalso nullable b
    | nullable (Star _) = true
  (* Course standard form: recursively, every Star body excludes epsilon.
   * The oracle below separately handles nullable stars for direct checks. *)
  fun standard Zero = true
    | standard One = true
    | standard (Char _) = true
    | standard (Plus (a,b)) = standard a andalso standard b
    | standard (Times (a,b)) = standard a andalso standard b
    | standard (Both (a,b)) = standard a andalso standard b
    | standard (Star a) = standard a andalso not (nullable a)
end

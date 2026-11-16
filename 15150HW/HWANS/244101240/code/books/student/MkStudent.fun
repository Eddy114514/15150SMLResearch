(* Your functor MkStudent goes here. *)
functor MkStudent(val count: int 
                  val favWord: string) :> STUDENT =
    struct
        type thoughts = string list
        datatype status
            = YES
            | NO
            | MAYBE of thoughts * Book.direction
        val start = []

        fun check [] acc = acc = count
          | check (x::xs) acc = 
            if acc = count then true 
            else if x = favWord then check xs (acc+1)
            else check xs acc

        fun boolToInt true = 1 | boolToInt false = 0

        fun think (t,(b, NONE)) = if (check t 0) then YES else NO
          | think (t,(b, SOME(c))) = if (check t (boolToInt(c = favWord))) then YES else MAYBE(c::t, Book.FORWARD)                     
    end
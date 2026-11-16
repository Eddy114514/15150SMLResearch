(* Write the Reset structure here! *)
structure Reset :> STUDENT =
    struct
        type thoughts = unit
        type thoughts = unit
        datatype status = YES | NO | MAYBE of thoughts * Book.direction

        val start = ()

        fun think (_, (true, _)) = YES
          | think (_, _) = MAYBE((),Book.BACKWARD)
    end
(* Write a negation functor called MkNemesis here! *)
functor MkNemesis(take: STUDENT) :> STUDENT =
    struct
        type thoughts = take.thoughts
        val start = take.start
        datatype status
            = YES
            | NO
            | MAYBE of thoughts * Book.direction
        fun invertStatus (status: take.status) =
          case status of
              take.YES => NO
            | take.NO => YES
            | take.MAYBE(t,d) => MAYBE(t,d)

        fun think (t: thoughts, p) = invertStatus (take.think (t, p))
    end
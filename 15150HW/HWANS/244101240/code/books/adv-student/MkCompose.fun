(* Implement MkCompose, taking in StudentA and StudentB, here! *)
functor MkCompose(structure StudentA: STUDENT
                  structure StudentB: STUDENT) :> STUDENT =
struct
    type thoughts = StudentA.thoughts * bool * StudentB.thoughts
    datatype status = YES | NO | MAYBE of thoughts * Book.direction

    val start = (StudentA.start, false, StudentB.start)

    fun think ((ta, AYes, tb), p) =
     if AYes then (case StudentB.think (tb, p) of
                     StudentB.NO => NO
                   | StudentB.YES => YES
                   | StudentB.MAYBE(newTB, dir) => MAYBE((ta, true, newTB), dir))
     else
      case StudentA.think (ta, p) of
             StudentA.NO => NO
           | StudentA.YES => think ((ta, true, tb),p)
           | StudentA.MAYBE(newTA, dir) => MAYBE((newTA, false, tb), dir)
end

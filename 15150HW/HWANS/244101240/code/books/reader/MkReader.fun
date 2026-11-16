(* Your MkReader functor, taking in a Student structure, goes here. *)
functor MkReader(take: STUDENT) :> READER =
    struct
        structure Student = take

        fun helpRead b t = 
        let
            val cp = Book.currentPage b
        in
            case Student.think(t, cp) of 
                Student.YES => true
            |   Student.NO => false
            |   Student.MAYBE(new, dir) => helpRead (Book.flip dir b) new
        end

        fun read b = helpRead b Student.start
    end
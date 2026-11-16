(* Implement your Book structure here! *)
structure Book :> BOOK =    
    struct
        type page = string
        datatype direction = FORWARD | BACKWARD
        type book = page list * page option * page list

        exception OutOfBounds

        fun bind [] = ([], NONE, [])
          | bind (l::ls) = ([], SOME(l),ls)
        
        fun unbind (_, NONE, _) = []
          | unbind (front, SOME(l), back) = List.rev(front) @ (l::back)

        fun currentPage ([], NONE, []) = (true, NONE)
          | currentPage (_, NONE, []) = (false, NONE)
          | currentPage ([], SOME(c), _) = (true, SOME(c))          
          | currentPage (_, SOME(c), _) = (false, SOME(c)) 
        

        fun flip _ ([], NONE, []) = raise OutOfBounds
          | flip FORWARD (_, NONE, []) = raise OutOfBounds
          | flip BACKWARD (f::fs, NONE, []) = (fs, SOME(f), [])
          | flip dir (front, SOME(c), back) =  
            case (dir, front, back) of
                (FORWARD, fs, []) => (c::fs, NONE, [])
            |   (BACKWARD,[], _) => raise OutOfBounds
            |   (FORWARD, fs, (b::bs)) => (c::fs, SOME(b), bs)
            |   (BACKWARD, (f::fs), bs) => (fs, SOME(f), c::bs)



    end

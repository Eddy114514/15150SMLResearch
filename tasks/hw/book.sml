(* @solution *)
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
(* @manual hw_book_bind *)
(* @contract hw_book_bind
 * Original: Book.bind : string list -> Book.book.
 * The initial snapshot records contents and currentPage after bind.
 * All input page occurrences must remain in input order, but the bind comment
 * does not say only those pages may be encoded. If input is nonempty, observe
 * its first page as current. No beginning flag, empty-book condition for empty
 * input, or requirement on later flip observations is added.
 *)
functor ManualContract (Helpers : sig end) = struct
  type input = string list
  type output = BookCase.snapshot * BookCase.step list
  fun requires (_ : input) = true
  fun subsequence [] _ = true
    | subsequence _ [] = false
    | subsequence (wanted as p::ps) (q::qs) =
        if p = q then subsequence ps qs else subsequence wanted qs
  fun ensures pages ((contents,(_,current)),_) =
    subsequence pages contents andalso
    (case pages of [] => true | first::_ => current = SOME first)
end
(* @manual hw_book_current_page *)
(* @contract hw_book_current_page
 * Original currentPage : Book.book -> bool * string option.
 * Input is a lossless reachable-state description (pages,cursor).
 *)
functor ManualContract (Helpers : sig end) = struct
  type input = string list * int
  type output = BookCase.view
  fun requires (pages,i) = 0 <= i andalso i <= List.length pages
  fun ensures (pages,i) result = result = BookModel.view pages i
end
(* @manual hw_book_flip *)
(* @contract hw_book_flip
 * Original flip : Book.direction -> Book.book -> Book.book.
 * Observe the actual returned book, or prescribed OutOfBounds, plus contents.
 *)
functor ManualContract (Helpers : sig end) = struct
  type input = string list * int * BookCase.direction
  type output = BookCase.observedStep
  fun requires (pages,i,_) = 0 <= i andalso i <= List.length pages
  fun ensures (pages,i,d) result =
    result = (#2 (BookModel.advance pages i d),pages)
end
(* @manual hw_book_trace *)
(* @contract hw_book_trace
 * All states, content observations and prescribed exceptions are compared.
 *)
functor ManualContract (Helpers : sig end) = struct
  type input = string list * BookCase.direction list
  type output = BookCase.snapshot * BookCase.observedStep list
  fun requires (_ : input) = true
  fun ensures (pages,ds) result = result = BookModel.trace pages ds
end

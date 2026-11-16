functor MkTest (Book : BOOK) :> TEST =
struct
  exception Error

  val test = fn () =>
    let
      val B0 = Book.bind []

      val () = (
        case Book.currentPage B0 of
          (true, NONE) => ()
        | _ => raise Error
      )

      val () = (
        case Book.unbind B0 of
          [] => ()
        | _ => raise Error
      )

      (* testing for unhandled Book.OutOfBounds exception *)
      val () = let val _ = Book.flip Book.FORWARD B0 in raise Error end handle Book.OutOfBounds => ()

      val B1 = Book.bind ["1","2","3"]

      (* Add more tests here *)
      val () = (
        case Book.currentPage B1 of
          (true, SOME("1")) => ()
        | _ => raise Error
      )

      val B2 = Book.flip Book.FORWARD B1
      val () = (
        case Book.currentPage B2 of
          (false, SOME("2")) => ()
        | _ => raise Error
      )

      val B3 = Book.flip Book.FORWARD B2
      val () = (
        case Book.currentPage B3 of
          (false, NONE) => ()
        | _ => raise Error
      )

      val () = let val _ = Book.flip Book.FORWARD B3 in raise Error end handle Book.OutOfBounds => ()

      val P2 = Book.flip Book.BACKWARD B3
      val () = (if Book.currentPage B2 = Book.currentPage P2 then () else raise Error)

      val P1 = Book.flip Book.BACKWARD P2
      val () = (if Book.currentPage P1 = Book.currentPage B1 then () else raise Error)

      val () = let val _ = Book.flip Book.BACKWARD P1 in raise Error end handle Book.OutOfBounds => ()

      val () = (if Book.unbind P1 = ["1","2","3"] then () else raise Error)

      val () = (
        case Book.currentPage (Book.bind []) of
          (true, NONE) => ()
        | _ => raise Error
      )


      val singal = Book.bind ["114514"]
      val () = (
        case Book.currentPage singal of
          (true, SOME("114514")) => ()
        | _ => raise Error
      )
      val () = let val _ = Book.flip Book.BACKWARD singal in raise Error end handle Book.OutOfBounds => ()
      val () = let val _ = Book.flip Book.FORWARD singal in raise Error end handle Book.OutOfBounds => ()

      val () = (if Book.unbind singal = ["114514"] then () else raise Error)
      




    in
      ()
    end
end

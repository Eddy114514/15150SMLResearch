structure Find150 :> sig val is150Book : Book.page list -> bool end =
struct

  structure negHonk = MkNemesis(Honk)
  structure resetNegHonk = MkCompose(structure StudentA = Reset structure StudentB = negHonk)
  structure both = MkCompose(structure StudentA = Polly structure StudentB = resetNegHonk)
  structure R = MkReader(both)

  (* is150Book : Book.page list -> bool
   * REQUIRES: true
   * ENSURES:
   *   is150Book b = true iff b contains at least three instance of
   *   the word "lambda" and no instances of the word "pointer"
   *)
  fun is150Book b = 
      R.read (Book.bind b)
end

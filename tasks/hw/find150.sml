(* @solution *)
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

(* @manual hw_find150 *)
(* @contract hw_find150
 * Find150.is150Book : string list -> bool
 * REQUIRES: true.
 * ENSURES: The result is true exactly when the book contains at least three
 * pages equal to "lambda" and no page equal to "pointer".
 * The solution's module dependencies are loaded directly from HWANS.
 *)
functor ManualContract (Helpers : sig end) = struct
  type input = string list
  type output = bool
  fun requires (_ : input) = true
  fun ensures pages result =
    result = (List.length (List.filter (fn page => page = "lambda") pages) >= 3
              andalso not (List.exists (fn page => page = "pointer") pages))
end

type vault = exn list


(* get      : 'a key -> vault -> 'a option
 * REQUIRES : M was produced from a valid sequence of operations for a vault
 * ENSURES  : get k M ==> SOME y   if there exists x in M such that
 *                                    decrypt k x ==> SOME y
 *                        NONE     otherwise
 *)
fun get (k : 'a key) ([] : vault) : 'a option = NONE
  | get (k) (x::xs) = case decrypt k x of 
                      NONE => get(k)(xs)
                     | x => x 


(* replace  : 'a key -> 'a -> vault -> 'a option * vault
 * REQUIRES : M was produced from a valid sequence of operations for a vault
 * ENSURES  : replace k v M ==> (SOME y, M')   if there exists x in M such that
 *                                                decrypt k x = SOME y and M'
 *                                                contains x' = encrypt k v
 *                                                instead of x
 *                              (NONE, M)      otherwise
 *)
fun replace (k : 'a key) (v : 'a) ([] : vault) : 'a option * vault = (NONE, [])
  | replace k v (x::xs) = case get k (x::xs) of 
                            NONE => (NONE, x::xs)
                           |SOME(y) => (SOME(y), ((encrypt k v) :: xs))

(* deposit  : 'a key -> 'a -> vault -> vault
 * REQUIRES : M was produced from a valid sequence of operations for a vault
 * ENSURES  : deposit k v M ==> M' such that M' contains x = encrypt k v,
 *            no other values x' = encrypt k v' (for any value v'),
 *            and all values y in M such that decrypt k y = NONE
 *)
fun deposit (k : 'a key) (v : 'a) (M : vault) : vault = (encrypt k v) :: M

(* withdraw : 'a key -> vault -> vault
 * REQUIRES : M was produced from a valid sequence of operations for a vault
 * ENSURES  : withdraw k M ==> M' where M' contains all elements x of M
 *              such that decrypt k x ==> NONE (and no others)
 *)
fun withdraw (k : 'a key) ([] : vault) : vault = []
  | withdraw (k)(x::xs) = 
  case decrypt k x of 
      NONE => x::(withdraw k xs)
    | _ => xs

val strkey : string key = new ()
val intkey1 : int key = new ()
val intkey2 : int key = new ()
val v : vault = [] (* the initial vault *)
val v = deposit intkey1 15150 v
val v = deposit strkey " WorkHard " v
val () = Test.int_option (" test1 ", SOME 15150 , get intkey1 v )
val () = Test.int_option (" test2 ", NONE , get intkey2 v )
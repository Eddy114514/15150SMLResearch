(* pascal : int * int -> int
 * REQUIRES: n >= k >= 0
 * pascal (n, k) ==> the element of Pascal's triangle at position (n,k)
 *)
fun pascal (n : int, k : int) : int = 
    if k = 0 orelse k = n then
      1
    else
      pascal(n-1,k-1) + pascal(n-1,k)

(* TEST CASES *)
(* Write test cases here *)
val 5005 = pascal(15,6)
val 1 = pascal(0,0)
val 1 = pascal(1,0)
val 48620 = pascal(18,9)
val 1 = pascal(5,5)
# Basis integers

Bindings `Int` and `IntInf` are available, including during isolated predicate compilation.

```sml
Int.min      : int * int -> int
Int.max      : int * int -> int
Int.abs      : int -> int
Int.compare  : int * int -> order
Int.precision : int option
Int.minInt   : int option
Int.maxInt   : int option
Int.quot     : int * int -> int
Int.rem      : int * int -> int
IntInf.fromInt : int -> IntInf.int
IntInf.toInt   : IntInf.int -> int
IntInf.+       : IntInf.int * IntInf.int -> IntInf.int
IntInf.-       : IntInf.int * IntInf.int -> IntInf.int
IntInf.*       : IntInf.int * IntInf.int -> IntInf.int
IntInf.compare : IntInf.int * IntInf.int -> order
```

`Int.min (a,b)` and `Int.max (a,b)` take tuples. Host `int` is not assumed unbounded or universally 31-bit. Inspect optional bounds; fixed-width arithmetic and `abs minInt` may raise `Overflow`.

`div` rounds toward negative infinity; `mod` has the divisor's sign when nonzero. `quot` rounds toward zero; `rem` has the dividend's sign. Thus `~7 div 3 = ~3`, `~7 mod 3 = 2`, `Int.quot (~7,3) = ~2`, `Int.rem (~7,3) = ~1`. Zero divisors raise `Div`.

`IntInf` supplies arbitrary-precision arithmetic and integer comparisons; converting back with `toInt` can overflow. When the contract requires mathematical sums, convert each operand before adding and compare in the same domain: `List.foldl (fn (x,a) => IntInf.+ (IntInf.fromInt x,a)) (0 : IntInf.int) xs = IntInf.fromInt n`. Do not add machine integers first or silently reinterpret other contract arithmetic.

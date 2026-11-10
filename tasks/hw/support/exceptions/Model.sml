(* Independent finite command semantics, shared by predicates. *)
structure CommandModel = struct
  open CommandCase
  fun writes name (Assign (key,_)) = name = key
    | writes name (If (_,yes,no)) = List.exists (writes name) (yes @ no)
    | writes name (Loop (counter,_,body)) =
        name = counter orelse List.exists (writes name) body
    | writes _ _ = false

  fun valid (If (_,yes,no)) = List.all valid (yes @ no)
    | valid (Loop (counter,count,body)) =
        not (List.exists (writes counter) body)
        andalso List.all valid body
    | valid _ = true

  (* This model appends assignment history and uses data for control signals.
   * It does not call Target or reproduce the solution's exception handlers. *)
  fun expected bindings action =
    case action of
      Assign binding => Completed (bindings @ [binding])
    | Break => Broke bindings
    | Continue => Continued bindings
    | Return value => Returned value
    | If (condition,yes,no) => commands bindings (if condition then yes else no)
    | Loop (counter,count,body) =>
        let
          fun repeat remaining history =
            if remaining <= 0 then Completed history
            else
              case commands (history @ [(counter,count-remaining+1)]) body of
                Completed next => repeat (remaining-1) next
              | Continued next => repeat (remaining-1) next
              | Broke next => Completed next
              | Returned value => Returned value
        in repeat count (bindings @ [(counter,0)]) end
  and commands bindings [] = Completed bindings
    | commands bindings (action::rest) =
        case expected bindings action of
          Completed next => commands next rest
        | signal => signal

  fun matches bindings actual = let
    (* get observes the first binding, independent of shadowed representation.
     * Input descriptions are assignment histories, so their latest value wins. *)
    fun lookup entries name = Option.map (fn (_,value) => value)
      (List.find (fn (key,_) => key = name) entries)
    val names = List.map (fn (name,_) => name) (bindings @ actual)
  in
    List.all (fn name => lookup actual name = lookup (List.rev bindings) name) names
  end
end

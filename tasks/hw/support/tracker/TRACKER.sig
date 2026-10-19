(* Course interface from sequences/code/aiv-tracker/tracker/TRACKER.sig. *)
signature TRACKER = sig
  type tracker
  type mascot = int
  type chat = mascot Seq.t
  val empty : int -> tracker
  val addChat : tracker -> chat -> tracker
  val query : tracker -> mascot -> int -> mascot Seq.t
end

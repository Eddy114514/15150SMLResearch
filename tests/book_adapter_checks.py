"""Check Book adapter observations and effects with an instrumented target.

Run from any directory: python3 tests/book_adapter_checks.py (requires sml).
"""
from pathlib import Path
import subprocess


ROOT = Path(__file__).resolve().parents[1]
PROGRAM = r'''
use "tasks/hw/support/book/Shared.sml";
structure Target = struct
  structure Book = struct
    datatype direction = FORWARD | BACKWARD
    exception OutOfBounds
    val calls = ref ([] : string list)
    val failure = ref ""
    fun record name = calls := name :: !calls
    fun bind pages = (record "bind"; (pages,0))
    fun unbind (pages,_) =
      (record "unbind";
       if !failure = "unbind" then raise OutOfBounds else pages)
    fun currentPage (pages,i) =
      (record "view";
       if !failure = "view" then raise OutOfBounds else
       (i = 0, if i = List.length pages then NONE else SOME (List.nth (pages,i))))
    fun flip direction (pages,i) =
      (record (case direction of FORWARD => "forward" | BACKWARD => "backward");
       if !failure = "flip" then raise Fail "unexpected flip exception" else
       if !failure = "early" andalso i = 1 then raise OutOfBounds else
       case direction of
         FORWARD => if i = List.length pages then raise OutOfBounds else (pages,i+1)
       | BACKWARD => if i = 0 then raise OutOfBounds else (pages,i-1))
  end
end;
use "tasks/hw/support/book/BookTarget.sml";
use "tasks/hw/support/book/BindTarget.sml";
structure Bind = TargetAdapter;
use "tasks/hw/support/book/TraceTarget.sml";
structure Trace = TargetAdapter;
structure B = Target.Book;

val _ = let
  open BookCase
  fun assert label ok = if ok then () else raise Fail label
  fun reset failure = (B.calls := []; B.failure := failure)
  fun calls expected = assert "target call order" (List.rev (!B.calls) = expected)
  fun bounds thunk =
    ((ignore (thunk ()); false) handle B.OutOfBounds => true)
  fun unexpected thunk =
    ((ignore (thunk ()); false) handle Fail _ => true)

  val _ = reset ""
  val _ = assert "bind observations"
    (Bind.run ["a","b"] =
      ((["a","b"],(true,SOME "a")),
       [Moved (false,SOME "b"),Moved (false,NONE)]))
  val _ = calls ["bind","unbind","view","forward","view","forward","view"]

  val _ = reset ""
  val _ = assert "empty bind does not flip" (Bind.run [] = (([],(true,NONE)),[]))
  val _ = calls ["bind","unbind","view"]

  val _ = reset "early"
  val _ = assert "bind stops at first bounds exception"
    (Bind.run ["a","b","c"] =
      ((["a","b","c"],(true,SOME "a")),
       [Moved (false,SOME "b"),OutOfBounds (false,SOME "b")]))
  val _ = calls ["bind","unbind","view","forward","view","forward","view"]

  val _ = reset ""
  val _ = assert "trace retains state after bounds exception"
    (Trace.run (["a"],[Backward,Forward,Forward,Backward]) =
      ((["a"],(true,SOME "a")),
       [(OutOfBounds (true,SOME "a"),["a"]),
        (Moved (false,NONE),["a"]),(OutOfBounds (false,NONE),["a"]),
        (Moved (true,SOME "a"),["a"])]))
  val _ = calls ["bind","unbind","view",
    "backward","view","unbind","forward","view","unbind",
    "forward","view","unbind","backward","view","unbind"]

  val _ = reset "flip"
  val _ = assert "unexpected flip exception escapes"
    (unexpected (fn () => BookTarget.move (["a"],0) Forward))
  val _ = calls ["forward"]
  val _ = reset "view"
  val _ = assert "view exception is not treated as flip bounds"
    (bounds (fn () => BookTarget.move (["a"],0) Forward))
  val _ = calls ["forward","view"]
  val _ = reset "unbind"
  val _ = assert "unbind exception escapes"
    (bounds (fn () => BookTarget.step (["a"],0) Forward))
  val _ = calls ["forward","view","unbind"]
in print "BOOK_ADAPTER_CHECKS_PASSED\n" end
handle error => (TextIO.output (TextIO.stdErr, General.exnMessage error ^ "\n");
                 OS.Process.exit OS.Process.failure);
OS.Process.exit OS.Process.success;
'''


def main():
    result = subprocess.run(["sml"], input=PROGRAM, cwd=ROOT, text=True,
                            capture_output=True, timeout=30)
    if result.returncode or "BOOK_ADAPTER_CHECKS_PASSED" not in result.stdout.splitlines():
        raise SystemExit(result.stdout + result.stderr)
    print("Book adapter observations, call order, bounds stops and exception boundaries passed.")


if __name__ == "__main__":
    main()

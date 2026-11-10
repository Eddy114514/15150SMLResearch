Shared public observations, not the abstract Book representation:
datatype BookCase.direction = Forward | Backward
type BookCase.view = bool * string option
type BookCase.snapshot = string list * BookCase.view
datatype BookCase.step = Moved of BookCase.view | OutOfBounds of BookCase.view
type BookCase.observedStep = BookCase.step * string list
Qualify all constructors with BookCase. A view is (atBeginning,currentPage); at the end currentPage=NONE, and an empty book is both at beginning and end. A snapshot is (allContents,view). observedStep records the outcome's view plus the actual post-step unbind contents; prescribed OutOfBounds retains the old book.
- BookModel.view : string list -> int -> BookCase.view. Independent cursor view. Requires 0 <= cursor <= length pages.
- BookModel.advance : string list -> int -> BookCase.direction -> int * BookCase.step. Independent next cursor and event. Same cursor precondition; forward at end and backward at beginning are OutOfBounds.
- BookModel.trace : string list -> BookCase.direction list -> BookCase.snapshot * BookCase.observedStep list. Starting at cursor 0, observes each direction, preserving contents and retaining cursor on OutOfBounds. No preconditions.
Every target invocation builds fresh Book values. Model operations never invoke the student's Book. Finite traces do not establish all possible state histories.
For bind, input is the page list and output is (initialSnapshot,walkSteps). Its source comment requires the input pages to be encoded in order and, for nonempty input, the first input page to be current. It does not say only those pages may occur. The functional reference checks the input as a subsequence of initial contents and checks the current-page value when input is nonempty; it adds no beginning-bit or empty-input restriction. Walk steps are additional observations of flip, not additional obligations imposed on bind.

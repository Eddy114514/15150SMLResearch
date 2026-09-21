# QCheck/SML dependency

- Upstream: [Christopher League's QCheck/SML](https://github.com/league/qcheck).
- Fixed commit: `92a43445779e6098a79175b41bba76ab90667256`.
- License: [qcheck/LICENSE](qcheck/LICENSE), Christopher League's two-clause BSD-style redistribution terms, retained unchanged.
- Full Git history and tags remain in the local clone. The upstream version rule uses `git describe --tags --dirty=+`.
- No upstream source patch or change to QCheck semantics was needed. The existing build works with this project's SML/NJ 110.79 environment.

The current `vendor/qcheck/` build is used directly. Its original Make rules generate the required version and SML/NJ-specific modules; those files are not handwritten replacements. This dependency is the native SML library, not a similarly named Python or OCaml package.

`sml/Generators.sml` combines `QCheck.Gen` generators with fixed boundary samples. `sml/Runner.sml` supplies a real `QCheck.implies` / `QCheck.pred` property to `QCheck.cpsCheck`, which owns iteration, accepted counts and failure collection. The adapter records exception phases before `pred` hides exceptions. An empty shrinker preserves the original input, but this version still confirms a failure by executing the property again; actual target calls are counted separately from original candidates. All project-generated execution files use the same pinned dependency.

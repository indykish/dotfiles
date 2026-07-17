# Rust authoring

Use ownership and borrowing to make resource lifetime visible. Keep `unsafe`
blocks small and state the invariant they rely on. Preserve error variants until
the caller has enough information to decide whether to retry or stop.

Test feature combinations selected by the repository profile. Concurrency work
needs a deterministic contention test, not only a happy-path asynchronous test.

The repository profile owns formatting, Clippy, build, test, security, and
benchmark commands.

# Rust authoring

Use ownership and borrowing to make resource lifetime visible. Keep `unsafe`
blocks small and state the invariant they rely on. Preserve error variants until
the caller has enough information to decide whether to retry or stop.

Test the feature combinations the repository actually builds. Concurrency work
needs a deterministic contention test, not only a happy-path asynchronous test.

The repository owns formatting, Clippy, build, test, security, and benchmark
commands — it declares them in `.oracle/orly.json`.

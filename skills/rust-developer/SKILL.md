---
name: rust-developer
description: Writes and reviews production Rust - tokio async without blocking the runtime, thiserror and anyhow error handling, no unwrap or expect on production paths, unsafe only with a SAFETY comment and tests, and the cargo fmt, clippy, test and deny gates, with proptest, criterion and loom where they apply. Use when writing, changing or reviewing Rust code or a Cargo workspace. For language-agnostic latency work use low-latency-systems.
---

# Rust Developer

## Overview

The compiler rules out a lot; it does not rule out panics on bad input, a blocked async runtime, wrong
`unsafe` invariants, or silent overflow in release builds. These rules cover those gaps, and the gates at
the end must pass before a change is done.

## Errors

- Libraries define error enums with `thiserror`. Binaries and application edges use `anyhow` and add
  context with `.context("...")` at each layer.
- No `unwrap()`, `expect()`, `panic!`, `unreachable!` or panicking indexing (`v[i]` with an untrusted
  index) on production paths. Use `?`, `ok_or`, `let ... else`, `get()`. They are fine in tests, build
  scripts and examples.
- Enforce it in the crate root:
  `#![cfg_attr(not(test), deny(clippy::unwrap_used, clippy::expect_used, clippy::panic))]`.
- Some examples in rust-patterns and rust-testing call `expect()` or `panic!` outside tests. They
  illustrate other points; on production paths the rule here wins.

## Async with tokio

- Never block the runtime: no `std::fs`, `std::thread::sleep`, blocking network calls or long CPU work on
  async tasks. Use `tokio::fs`, `spawn_blocking`, or a dedicated thread.
- Do not hold a `std::sync::Mutex` guard across `.await` (clippy's `await_holding_lock` catches it). Use
  `tokio::sync::Mutex` only when the lock must be held across an await.
- In `tokio::select!`, every branch must be cancel-safe or documented as not; partial reads such as
  `read_exact` lose data when cancelled.
- Bounded channels (`mpsc::channel(n)`) for backpressure; `tokio::time::timeout` on every external call;
  check `JoinHandle` results; shut down gracefully with a cancellation token.

## unsafe

- Every `unsafe` block has a `// SAFETY:` comment directly above it stating the invariants it relies on.
- Keep it minimal and behind a safe wrapper; add `#![deny(unsafe_op_in_unsafe_fn)]` and the clippy lint
  `undocumented_unsafe_blocks`.
- Test it, and run Miri (`cargo +nightly miri test`) on the crates that contain it where Miri supports them.

## Types and Arithmetic

- Newtypes for ids, units and money (`struct Cents(i64)`), never `f64` for money (use integer minor units
  or `rust_decimal`).
- Release builds wrap on overflow unless `overflow-checks = true` is set in the profile. Use
  `checked_*`, `saturating_*` or `wrapping_*` explicitly where overflow is possible.
- `#[must_use]` on results callers must not drop; `#[non_exhaustive]` on public enums that will grow.

## Concurrency

- Prefer message passing. `Arc<Mutex<_>>` is fine at low contention.
- Lock-free code (atomics, custom queues) only with loom tests under `#[cfg(loom)]`, and every
  `Ordering` other than `SeqCst` justified in a comment.

## Testing

- Unit tests next to the code, integration tests in `tests/`.
- `proptest` for parsers, encoders and invariants (round trip, idempotence, ordering).
- `criterion` benchmarks for hot paths, compared against a saved baseline before and after the change.

## Supply Chain

- `cargo deny check` with a committed `deny.toml` (advisories, licences, bans, sources).
- Commit `Cargo.lock` for binaries; enable only the features you use.

## Verify Before Done

```bash
cargo fmt --all -- --check
cargo clippy --workspace --all-targets --all-features -- -D warnings
cargo test --workspace --all-features
cargo deny check
# unwrap/expect/panic outside tests: each hit moves to a test or becomes `?`
# (hits inside #[cfg(test)] modules in src/ are fine; check them by eye)
grep -rnE '\.unwrap\(\)|\.expect\(|panic!\(' --include='*.rs' src/ crates/ 2>/dev/null | grep -v '/tests/'
# Every unsafe block is preceded by a SAFETY comment: the two counts should match
grep -rc 'unsafe {' --include='*.rs' src/ crates/ 2>/dev/null | awk -F: '{s+=$2} END {print s}'
grep -rn -B2 'unsafe {' --include='*.rs' src/ crates/ 2>/dev/null | grep -c 'SAFETY:'
# Lock-free code: model-check it
RUSTFLAGS='--cfg loom' cargo test --release <loom-test-filter>
# Hot-path changes: compare against the baseline saved before the change
cargo bench -- --baseline before
```

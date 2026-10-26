---
name: cpp-developer
description: Builds, tests and hardens C++20 projects - RAII with no raw new or delete, CMake presets, clang-tidy, ASan/UBSan and TSan builds, no allocation or locks on hot paths, and fuzzed protocol parsers (FIX and binary formats). Use when writing or reviewing C++ that ships, or setting up or changing its CMake build, sanitizer CI matrix or fuzzers. For choosing modern idioms see modern-cpp; for latency methodology see low-latency-systems.
---

# C++ Developer

## Overview

Modern idioms remove many bugs; the build, the sanitizers and the fuzzers find the rest. This skill covers
the project side: how the code is built, checked, and kept free of allocation and locking where latency
matters. Preset names below are conventions; use the project's own.

## Build

- `CMakePresets.json` with configure, build and test presets: `debug`, `release` (RelWithDebInfo), `asan`
  (ASan + UBSan), `tsan`, `fuzz`.
- `CMAKE_CXX_STANDARD 20`, `CMAKE_CXX_STANDARD_REQUIRED ON`, `CMAKE_CXX_EXTENSIONS OFF`,
  `CMAKE_EXPORT_COMPILE_COMMANDS ON` (clang-tidy needs it).
- Warnings as errors per target with `target_compile_options`, not global flags.
- Dependencies pinned: `FetchContent` with a commit hash, or a package manager lockfile.

## Ownership

- RAII for every resource: memory, file descriptors, sockets, locks, mappings.
- No raw `new` or `delete` outside a low-level allocator; containers and `std::unique_ptr` own memory.
  Raw pointers and references only observe.
- Rule of zero by default. `std::span` and `std::string_view` for non-owning parameters, never stored past
  the owner's lifetime.

## Static Analysis

- A committed `.clang-tidy` enabling `bugprone-*`, `concurrency-*`, `cppcoreguidelines-*`,
  `performance-*`, `modernize-*` and `cert-*`, with `bugprone-*` and `concurrency-*` as errors.
- Run it on the changed files in CI.

## Sanitizers

- The ASan + UBSan preset runs the whole test suite in CI, with `-fno-sanitize-recover=all` so undefined
  behaviour fails the test.
- The TSan preset runs the concurrency tests. ASan and TSan cannot be combined in one build.

## Hot Paths

- No heap allocation after warm-up: preallocate, use pools, arenas or `std::pmr::monotonic_buffer_resource`,
  and fixed-capacity containers.
- No locks: single-writer designs and SPSC queues. No exceptions thrown, no `std::function` that
  allocates, no iostreams, no formatted logging (write binary records to a ring buffer instead).
- Prove it: a test binary that replaces `operator new` with a counting version asserts zero allocations
  across the hot loop, and a benchmark guards the latency.

## Protocol Parsers (FIX and Binary)

- Treat every byte as hostile. Check every length field against the bytes remaining before reading.
- No `memcpy` into structs with an assumed layout. Read fields explicitly, with explicit endianness
  (`std::endian`, `std::byteswap` in C++23).
- FIX: validate BodyLength (9) and CheckSum (10), reject duplicate or out-of-order header tags as the spec
  requires, and cap the message size.
- Fuzz every parser with libFuzzer under ASan and UBSan, from a seed corpus of real, scrubbed messages.
  Run it in CI for a fixed time, keep the corpus, and turn every crash into a regression test.

## Concurrency

- `std::jthread` with stop tokens; `std::scoped_lock` for multiple mutexes.
- Atomics with explicit memory orders, each non-`seq_cst` order justified in a comment.
- Lock-free structures only with stress tests under TSan, and a well-tested library where one exists.

## Verify Before Done

```bash
cmake --preset release && cmake --build --preset release && ctest --preset release --output-on-failure
cmake --preset asan && cmake --build --preset asan && ctest --preset asan --output-on-failure
cmake --preset tsan && cmake --build --preset tsan && ctest --preset tsan --output-on-failure -L concurrency
run-clang-tidy -p build/release -quiet <changed-files>    # or: clang-tidy -p build/release <file>
# Raw new/delete outside allocators: each hit needs a reason
grep -rnE '\bnew [A-Za-z_]|\bdelete\b' src/ include/
# Fuzz each changed parser for at least two minutes
./build/fuzz/<parser>_fuzzer -max_total_time=120 fuzz/corpus/<parser>/
```

---
name: low-latency-systems
description: Engineers and reviews latency-critical paths - p50, p99 and p999 measurement, no allocations or syscalls on hot paths, CPU pinning and isolation, backpressure, lock-free structures only with tests, and a sound benchmarking method. Use when a path has a latency budget in microseconds or low milliseconds (market data, order routing, matching, real-time pipelines) or when tail latency regresses. Not for web page speed or database query tuning (performance-optimization).
---

# Low-Latency Systems

## Overview

Average latency hides the problem; the tail is what users and counterparties feel. Measure percentiles
correctly, remove every source of unpredictable delay from the hot path, and prove each change with a
benchmark against a baseline on the same machine.

## Budget and Measurement

- Write the end-to-end budget and split it per stage, with a p99 target for each.
- This project's end-to-end budgets: matching engine p99 under 1 ms from order in to acknowledgement, API
  order round trip p99 under 20 ms in-region, WebSocket market data under 50 ms.
- Timestamp each stage with a monotonic clock (`CLOCK_MONOTONIC` or the TSC); record histograms
  (HdrHistogram) and report p50, p90, p99, p99.9, maximum and sample count. Never report only an average.
- Avoid coordinated omission: drive load open-loop and measure from the intended send time, not from when
  the previous request finished.

## Hot-Path Rules

- No heap allocation after warm-up.
- No syscalls: no blocking logging or file I/O, no contended mutexes (they become futex calls). The vDSO
  clock is fine.
- No page faults: pre-fault and lock memory (`mlock`), and consider huge pages.
- No exceptions, no unbounded loops, no work proportional to history.
- Cache-friendly data: contiguous arrays over pointer chasing, hot fields together, separate counters
  written by different threads by a cache line (64 bytes; 128 on some CPUs) to avoid false sharing.

## CPU and OS

- Isolate cores for hot threads (`isolcpus`, `nohz_full`, `rcu_nocbs`, or cgroup cpusets) and pin one hot
  thread per core.
- Move interrupts away from hot cores; set the CPU governor to `performance`; keep memory on the local NUMA
  node (`numactl --cpunodebind --membind`).
- Busy polling trades a whole core for latency; decide it per thread and write it down.
- Kernel-bypass networking only when measurement shows the kernel stack is the bottleneck.

## Backpressure

- Every queue between stages is bounded, and its full-queue policy is documented: drop the oldest snapshot
  (market data), block the producer, or reject (orders).
- Export queue depth as a metric and alert on it. Unbounded growth turns into allocation storms and
  unbounded latency.

## Lock-Free Code

- Only for a measured contention problem. Prefer a proven library (for example, an SPSC ring buffer).
- Custom lock-free code needs model checking (loom, relacy) or long stress runs under TSan, and every
  memory order documented.

## Benchmarking Method

- Warm up first. Pin threads, fix the CPU frequency, and keep other load off the machine.
- Many runs; report the distribution and its spread, not one number.
- Compare against a baseline from the same machine and configuration; record hardware, kernel and
  configuration with every result.
- Guard microbenchmarks against dead-code elimination (`black_box`, `DoNotOptimize`) and add an
  end-to-end benchmark, because microbenchmarks miss cache and scheduling effects.
- Gate CI on p99 relative to the baseline, not on the mean.

## Verify Before Done

Run these on the target hardware, in staging (strace in particular slows the process it traces):

```bash
cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor | sort | uniq -c   # expect: performance
cat /sys/devices/system/cpu/isolated                                           # hot cores are isolated
taskset -cp <tid>                                                               # each hot thread is pinned
# After warm-up, hot threads show almost no context switches, migrations or page faults
perf stat -e task-clock,context-switches,cpu-migrations,page-faults -t <tid> -- sleep 30
strace -f -c -p <pid>     # syscalls in steady state; attach briefly
perf record -g -t <tid> -- sleep 30 && perf report --stdio | head -60
# Compare p99 and p99.9 with the stored baseline
<latency-benchmark> --warmup 10s --duration 60s --histogram out.hgrm
```

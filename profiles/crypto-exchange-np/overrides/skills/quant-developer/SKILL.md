---
name: quant-developer
description: Builds and reviews production trading systems - research-to-production parity, deterministic replay, exact decimal or fixed-point money, latency budgets, pre-trade position and risk limits, and a kill switch. Use when implementing or changing strategy execution, order management, pricing, position or risk code that runs against live markets. Not for research or backtests (quant-researcher) or generic hot-path tuning.
---

# Quant Developer

## Overview

Production trading code has to do what the research said, do it the same way every time, never mis-count
money, stay inside its risk limits, and stop on command. Each section below is a property you can test.

## When to Use

- Strategy execution, order management, pricing, positions, P&L or risk code.
- Moving a researched strategy into production.
- Reviewing any change on the order path.

## This Project

The production "strategy" code here is the exchange's own pricing and risk: index and mark price, funding,
margin, liquidation, and any hedging of the insurance fund. The sections below apply to it, and:

- Pre-trade risk limits run on every user order in the gateway and the engine, market makers included.
- The kill switch works per market and globally: cancel-only, reduce-only and halt states, with the same
  restart rule (a restart never resumes trading on its own).
- Deterministic replay covers the matching engine and the risk engine together.

## Research-to-Production Parity

- Share the feature and signal code between research and production, or keep a parity test: replay the
  research dataset through the production pipeline and compare signals and target positions within a stated
  tolerance.
- Run the parity test in CI. A mismatch fails the build and prints the first diverging timestamp.

## Deterministic Replay

- Record every input as an ordered event log: market data, order acks and fills, timers, configuration
  changes, operator commands.
- The decision engine is a function of that log. No wall-clock reads (inject a clock), no unseeded
  randomness, no iteration over hash maps with unstable order in decision logic, no dependence on thread
  timing.
- Replaying a recorded session reproduces the same orders byte for byte. Use it for every incident.

## Money and Quantities

- Integer minor units, ticks and lots, or a fixed-scale decimal type. Never binary floating point.
- Quantise prices to the tick size and quantities to the lot size; enforce the minimum notional.
- Rounding mode is explicit per operation (for example, quantity always rounded down).
- Check overflow on price x quantity (use 128-bit integers or decimals); validate at every boundary
  where a value enters or leaves the system.

## Latency Budgets

- Write a budget per stage: market data decode, signal, risk check, order send, with p99 targets.
- Timestamp each stage with a monotonic clock in production; alert when a stage breaches its budget.
- Risk checks stay inside the budget. They are never skipped to meet it.

## Pre-Trade Risk Limits

Hard checks in the order path, before anything is sent:

- Maximum order quantity and notional; a price collar against a reference price (fat-finger check).
- Maximum position per instrument, and net and gross exposure.
- Maximum open orders and order rate (messages per second).
- Daily loss limit; self-trade prevention.

Limits come from versioned configuration; every change is audited. Every rejection carries an explicit
reason code.

## Kill Switch

- One action cancels all open orders and blocks new ones; flattening positions is a separate, explicit step.
- Triggered by a human and automatically: loss limit, error rate, stale market data, or a position mismatch
  with the venue.
- The state survives a restart: restarting the process must not resume trading.
- Tested on a schedule in a non-production environment.

## State and Reconciliation

- Reconcile orders and positions with the venue on start and periodically.
- Unique client order ids make sends idempotent. An order in an unknown state is treated as live until the
  venue confirms otherwise.
- Handle partial fills, cancels racing fills, and out-of-order acknowledgements.

## Failure Modes

| Failure | Guard |
|---|---|
| Trading on stale market data | Staleness check on the exchange timestamp, per instrument |
| Duplicate order after a retry | Client order id, check before resend |
| Restart loses state | Rebuild from venue reconciliation before trading resumes |
| Clock skew between hosts | Decisions use the injected clock; alert on skew |
| Venue disconnect mid-order | Order marked unknown, queried on reconnect |

## Verify Before Done

```bash
<test-cmd>     # the project's runner (pytest, cargo test, ctest), including risk-limit and kill-switch tests
# Money paths must not use binary floating point: each hit needs a reason
grep -rnE '\b(float|double|f32|f64)\b' <pricing-order-position-src>/
# Decisions must use the injected clock, not the wall clock
grep -rnE 'time\.time\(|datetime\.now\(|SystemTime::now|system_clock::now' <decision-src>/
# Replay is deterministic
<replay-cmd> --log <recorded-session> --out replay1.orders && <replay-cmd> --log <recorded-session> --out replay2.orders && cmp replay1.orders replay2.orders
<parity-test-cmd>    # research and production signals agree on the same data
grep -rlE 'kill_?switch|kill-switch' <tests-dir>/   # the kill switch has tests
```

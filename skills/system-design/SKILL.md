---
name: system-design
description: Designs or reviews the architecture of a service or distributed system before it is built - requirements and SLOs, capacity and cost, data model and ownership, consistency per flow, idempotency, partitioning and hot keys, event sourcing and CQRS, backpressure, failure handling, multi-AZ and disaster recovery, migration and rollback - and records the decision as an ADR. Use when designing a new service, splitting or merging services, changing how data is stored, partitioned or replicated, or choosing between architectures. Not for writing a feature spec (spec-driven-development) or breaking work into tasks (planning-and-task-breakdown).
---

# System Design

## Overview

Design from numbers, not adjectives. Every step below produces something checkable: a target with a unit, a
table, or an explicit decision with its trade-off. The output is an ADR that someone can disagree with
precisely.

## When to Use

- A new service, data store, queue or external integration.
- Changing how data is owned, partitioned, replicated or made consistent.
- Choosing between architectures (sync vs async, monolith module vs service, event sourcing or not).
- Reviewing a design doc or ADR (the lead-engineer agent applies this skill).

Not for: feature specs, task breakdowns, or line-level code review.

## Process

Work through the steps in order. Skip a step only by writing one line saying why it does not apply.

### 1. Requirements and SLOs first

- List the user-facing flows. For each: availability SLO (99.9% allows about 43 minutes of downtime a
  month), latency targets as percentiles (p50 and p99, in ms), durability, and freshness for read models.
- RPO (data you may lose) and RTO (time to recover) per data store.
- "Fast", "scalable" and "highly available" are not requirements. A requirement has a number and a unit.

### 2. Capacity and cost

- Peak requests per second = daily volume x peak-to-average factor / 86,400. Show the arithmetic.
- Storage = record size x records per day x retention, plus indexes and replicas.
- Size for 2x the expected peak, and say which component saturates first.
- Monthly cost of the main components at that size. A design nobody can afford is not a design.

### 3. Data model and ownership

- Write the access patterns (the queries) before the schema. Choose keys and indexes from them.
- One owning service per entity. Others read through its API or its events, never through its tables.
- Mark the entities that hold money, personal data or permissions; later steps treat them more strictly.

### 4. Consistency model per flow

Make a table: flow | consistency | mechanism | why.

- Strong: money movements, balances, inventory, permissions, uniqueness. Mechanism: a single writer, a
  serialisable transaction or row lock, or a conditional write. Where money is involved, strong is the
  default and eventual needs a written justification.
- Eventual: feeds, search, analytics, notifications. State the staleness bound in seconds.
- Across services there is no distributed transaction: use a transactional outbox with idempotent
  consumers, or a saga with an explicit compensation for every step.

### 5. Idempotency and exactly-once effects

- Assume at-least-once delivery everywhere. Exactly-once is an effect you build, not a delivery guarantee.
- Every externally triggered write takes an idempotency key stored with its result, so a retry returns the
  same response. Enforce uniqueness in the store (unique constraint or conditional put), not with
  read-then-write.
- Deduplication windows must be longer than the longest retry window of every caller.

### 6. Partitioning and hot keys

- Choose the partition key from the access patterns; estimate the share of traffic of the busiest key.
- Name the hot keys (a large account, a popular instrument, a viral item) and the mitigation: splitting the
  key, caching reads, or a single-writer queue for that key.
- Write down how data is rebalanced when partitions are added.

### 7. Event sourcing and CQRS

- Use them when a full audit trail, temporal queries or several independent read models are required.
- Cost to plan for: event schema evolution (versioned events, upcasting), replay time and snapshots, and
  read models that lag the write side.
- If an audit trail is the only need, an append-only audit table next to a normal model is usually enough.

### 8. Backpressure and load shedding

- Every queue and buffer is bounded. For each, write what happens when it is full: reject with
  429/503 and Retry-After, drop the lowest-priority work, or shed per tenant.
- Propagate deadlines: a downstream call never gets more time than its caller has left.

### 9. Failure modes, retries and timeouts

Make a table: dependency | failure | how it is detected | response.

- A timeout on every remote call, shorter than the caller's.
- Retries only for idempotent operations, capped, with exponential backoff and jitter, and a retry budget.
  Retry at one layer only, or retries multiply.
- Circuit breakers or bulkheads around dependencies that can stall the whole service.

### 10. Multi-AZ and disaster recovery

- RPO and RTO per store, and the replication that delivers them (synchronous across zones for RPO 0).
- Backups count only when a restore has been tested; record when.
- Region failure: active-passive or active-active, and which write conflicts active-active creates.
- A failover runbook with the decision owner named.

### 11. Migration and rollback

- Expand, migrate, contract. The backfill is restartable, throttled, and verified with counts or checksums.
- Dual-write or dual-read windows behind a feature flag.
- A rollback for each stage, and the point of no return named explicitly.

## Output: the ADR

Store it where the project keeps decisions (often `docs/adr/NNNN-title.md`; ask if there is no convention).

```markdown
# NNNN. <Decision title>

Status: Proposed | Accepted | Superseded by NNNN
Date: YYYY-MM-DD

## Context
<requirements and SLOs with numbers, constraints, the capacity estimate>

## Options
<at least two real options, each with its trade-offs against the requirements>

## Decision
<the option chosen and the consistency, failure-handling and migration choices that go with it>

## Consequences
<what gets easier, what gets harder, risks accepted, follow-up work with owners>
```

## Red Flags

| Seen in the design | Problem |
|---|---|
| "We will use eventual consistency" for balances | Double-spend and negative balances under concurrency |
| Retries at the client, the gateway and the service | Retry storms multiply load during an outage |
| No number next to an SLO or capacity claim | Nothing to test or alert on |
| Two services writing the same table | No owner, so no one can change its schema safely |
| "Exactly-once delivery" from a broker | Effects still duplicate on redelivery; idempotency is missing |
| Unbounded queue "for safety" | Memory exhaustion and unbounded latency instead of a clear rejection |
| Rollback plan is "redeploy the old version" after a schema change | Old code cannot read the new data |

## Verify Before Done

Adapt paths to the project:

```bash
# The ADR exists and has all four sections (expect 4)
grep -cE '^## (Context|Options|Decision|Consequences)$' docs/adr/NNNN-*.md
# Every SLO, capacity and recovery claim carries a number and a unit
grep -nE 'p(50|90|99|999)|RPO|RTO|req/s|QPS|[0-9]+ ?(ms|s|GB|TB)' docs/adr/NNNN-*.md
# The new code sets a timeout or deadline on its remote calls (adapt to the client library)
grep -rnE 'timeout|deadline' <new-service-dir>/
# The computed peak holds under load (k6 shown; use the project's load tool)
k6 run --vus <n> --duration 5m load/<scenario>.js
```

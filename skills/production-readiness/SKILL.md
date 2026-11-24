---
name: production-readiness
description: The bar for everything built here - code that can go to production without a rewrite. Targets with numbers (availability, latency, capacity, recovery) sized to the real need; stateless services that scale out; timeouts, retries with backoff and idempotency on remote calls; graceful degradation and health checks; config from the environment and secrets never in code; logs, metrics, traces and alerts; migrations with a rollback and tested backups; tests including a load test at the stated capacity, and CI. Use when planning, designing, building or reviewing any feature, service, app or job, unless the user labels the work a throwaway spike, prototype or demo. Not a launch checklist (shipping-and-launch) or a full architecture review (system-design).
---

# Production Readiness

## Overview

Whatever is built here is meant to reach production one day, whether it starts as a side project or a real
product. Production-ready means it can go live without a rewrite: correct, secure, observable, recoverable, and
able to grow to its stated target by adding resources rather than redesigning.

It does not mean over-built. Every mechanism is sized to a target with a number, and the change stays as small
as the bar allows: small and complete, never small and fragile. Complexity is a reliability risk too, so a
queue, cache, second region or new service needs the target or metric that calls for it.

## When It Applies

- **By default:** features, services, apps, APIs, data pipelines and jobs that will run unattended.
- **Partly:** a library or command-line tool skips the service-only items (health checks, scaling out,
  alerts); say which items you skipped and why.
- **Exempt:** work the user labels throwaway: a spike (the `spike` skill), a prototype, a demo, an experiment.
  Say in one line that it is exempt. Before such code moves toward production, list what it lacks against this
  bar; never promote it as it is.

## 1. Targets Before Design

- Get targets with numbers before choosing a design: availability (99.9% allows about 43 minutes of downtime a
  month), latency at p95 and p99, throughput and data size at launch and at 10x, and recovery (RPO: data you may
  lose; RTO: time to restore).
- If the user has none, propose targets that fit the stage and get a yes. For a first release, a reasonable
  start is 99.9% availability, p95 under 300 ms for user-facing reads, a written path to 10x, RPO of an hour or
  less and RTO of four hours or less. Tighter targets cost more; say what each costs.
- "Highly available", "scalable" and "fast" are not targets until they have a number and a unit.
- Write the targets where the work is tracked: the ticket's "Non-functional requirements", the PR body or the
  design doc. For a new service or a cross-service change, use `system-design` (in the `roles` pack).

## 2. Architecture That Scales Out

- **Stateless application tier.** Keep state in the database, cache, queue or object store, never only in a
  process's memory or local disk, so instances can be added, replaced and restarted at any time.
- **No silent single points of failure.** Name each one; give it the redundancy the availability target needs,
  or record why not yet and what would trigger it.
- **A written scale path.** What to add at 10x (replicas, read replicas, partitions, more consumers), the first
  bottleneck you expect, and the metric that will show it coming.
- **Bounded work.** One owner per table or stream; an index for every query path; pagination on every list;
  limits on request size, batch size and result size. No unbounded query, loop or payload.
- **Async for slow or bursty work.** Put it on a queue with retries and a dead-letter path instead of holding a
  request open.

## 3. Failure Handling

- **Every remote call** (database, cache, HTTP, queue, third-party API) has a timeout. Retries are bounded, use
  exponential backoff with jitter, and apply only to operations that are idempotent or carry an idempotency key.
- **Idempotency keys** on writes that a client, queue or webhook may repeat (payments, orders, messages).
- **Degrade, do not crash.** Serve cached or partial results, switch off a failing feature with a flag, and use
  a circuit breaker where one dependency's outage must not take the whole service down.
- **Validate input at the boundary** and fail closed on authentication and authorisation.
- **Services shut down gracefully** (drain in-flight work) and expose liveness and readiness checks.

## 4. Operability and Security

- Structured logs with a request or trace id; never secrets, tokens or personal data in logs.
- Metrics for each target in section 1 (request rate, errors, duration, saturation) and an alert for each
  target, with a short runbook entry for each alert.
- Traces across service boundaries once there is more than one service.
- Configuration from the environment or a config service. Secrets come from a secret store, never from code,
  the repository, an image or a log (see `security-and-hardening`).
- Reproducible builds: dependencies pinned with a lockfile, and one build artifact promoted through the
  environments.

## 5. Data Safety and Change

- Schema changes go expand, migrate, contract: each step deployable on its own and reversible; backfills
  restartable and throttled.
- Backups that meet the RPO, and a restore that has been run and meets the RTO.
- Releases behind a flag or a staged rollout, with a rollback that still works after data has been written in
  the new shape (see `shipping-and-launch`).

## 6. Proof

- Tests for behaviour and for failure paths: timeouts, retries, bad input, a dependency down (see
  `test-driven-development`).
- A load test at the stated capacity before a service is called ready, recording p95, p99 and the error rate.
  Run it again when a change touches a hot path.
- CI runs lint, type checks and tests on every pull request, and nothing merges red.
- Authorisation on every endpoint and a dependency audit (see `security-and-hardening`).

## Proportion by Stage

| Stage | Needed now | Designed for, built later |
|---|---|---|
| Labelled spike, prototype or demo | Nothing from this list; note what is missing | n/a |
| First production release | Sections 1 to 6 at the stated targets, in one region; backups; alerts | Multi-region, autoscaling past 10x, chaos testing |
| Growth | Autoscaling, read replicas or partitions once the metrics call for them; a load test each release | Whatever the next 10x needs |

## Output

When you finish building or reviewing, add a short "Production bar" note to your report or PR body:

```markdown
## Production bar
- Targets: <availability, latency, capacity, RPO/RTO, or "exempt: <label>">
- Met: <one line per section 1-6, with file:line or test name>
- Deferred: <item - why - what will trigger it>
```

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "It's only an MVP, production comes later" | Later means a rewrite. Meet the bar at a small target instead; only a labelled throwaway is exempt. |
| "We'll add timeouts and retries when it breaks" | It breaks in production, under load, at night. Timeouts are one line each now. |
| "Make it scale to millions just in case" | Unmeasured scale is complexity without a target. Size to the target and write down the 10x path. |
| "Logs are enough" | Logs say what happened after you look; metrics and alerts say it is happening now. |
| "Backups are on" | A backup that has never been restored is not a backup. |

## Verify Before Done

- [ ] Targets with numbers are written down, or the work is labelled exempt and says so.
- [ ] No state lives only in process memory or on local disk (services).
- [ ] Every remote call has a timeout; every retry is bounded and safe to repeat.
- [ ] Every list is paginated and every query has an index; no unbounded work.
- [ ] Secrets come from the environment or a secret store; none in code, logs or the repository.
- [ ] Metrics and an alert exist for each target (services).
- [ ] Schema changes are reversible; backups have a tested restore (when there is data).
- [ ] Tests cover failure paths; a load test at the stated capacity has run (services).
- [ ] The "Production bar" note lists what was met and what was deferred, with triggers.

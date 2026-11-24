## Production bar

- Everything built here is meant to reach production: design and build it so it can go live without a rewrite.
  Meet the bar in the `production-readiness` skill: targets with numbers, services that scale out, timeouts,
  bounded retries and idempotency, graceful degradation, logs, metrics and alerts, secrets out of code,
  reversible migrations, tested backups, and tests that include failure paths and a load test at the stated
  capacity.
- Size it to the targets, not beyond them: production-ready is not over-built. When no targets are given,
  propose them with numbers and get the user's yes.
- Only work the user labels throwaway (a spike, prototype or demo) is exempt. Before such code moves toward
  production, list what it lacks against the bar.

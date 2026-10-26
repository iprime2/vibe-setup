---
name: crypto-custody-and-keys
description: Designs and reviews custody of digital-asset keys - hot, warm and cold tiers, HSM or MPC signing, withdrawal policies with multi-party approval, destination allow-lists, key ceremonies and rotation, and keeping keys out of code, logs and environment dumps. Use when designing or changing wallet architecture, a signing service, withdrawal approval flows, or anything that generates, stores or uses private keys or seed material. Not for general application secrets (security-and-hardening) or chain integration code (blockchain-developer).
---

# Crypto Custody and Keys

## Overview

Whoever holds the keys holds the assets, and a signature cannot be taken back. Design so that a single
compromised server, person or key causes a bounded loss, every signature passes a policy check that the
signer itself enforces, and the controls are tested, not assumed.

## Tiers

- **Hot**: online and automated; holds only enough for a defined number of hours of withdrawals, with a
  hard cap. A hot-wallet compromise must be a bounded loss.
- **Warm**: online, but signing needs human approval or a time delay.
- **Cold**: offline or air-gapped (or MPC with offline shares); holds most of the funds.
- Target balances per tier, with sweep and refill procedures that need approval. Balances per tier are
  monitored metrics.

## Key Storage and Signing

- Keys live in an HSM (validated to FIPS 140-2/140-3 level 3 or equivalent) or in an MPC/threshold scheme.
  They are never exported in plaintext.
- One signing service talks to the HSM or MPC nodes, through an authenticated, audited API that evaluates
  policy before it signs. Application servers hold extended public keys only.
- No key material in source code, config files, environment variables, CI variables, container images,
  logs, crash dumps, analytics or error trackers. Disable core dumps on signing hosts and zeroise buffers
  after use.

## Withdrawal Policy

- Evaluated by the signing path before signing, not only in the UI:
  - limits per asset and per user, per transaction and per day; velocity checks;
  - destination allow-lists, with a cooling-off period and a notification when an address is added;
  - M-of-N approval by distinct people, with requester and approver always different;
  - time delays for large amounts;
  - a screening hook before release, as the compliance policy requires.
- Changes to the policy itself need multi-party approval and are audited.

## Key Ceremonies

- A written script with roles (lead, witnesses, auditor), air-gapped hardware, a recorded entropy source,
  tamper-evident storage, and a signed log of every step.
- Backups split (Shamir or SLIP-39 shares, or MPC share backups) and stored in separate secure locations.
- Recovery rehearsed on a schedule, with the date of the last successful rehearsal recorded.

## Rotation and Revocation

- Rotate when someone with key access leaves, on suspected compromise, and on a schedule. For on-chain
  addresses, rotation means moving funds to new keys; keep a runbook for it.
- MPC schemes: refresh or re-share key shares instead of moving funds where the scheme supports it.

## Monitoring and Incidents

- Alert on any signing request that fails policy, on new allow-list entries, on tier balances crossing
  thresholds, and on unexpected outflows seen on-chain by a monitor independent of the internal systems.
- A freeze switch stops the signing service. A compromised-key playbook sweeps the remaining funds using
  cold-approved transactions.

## Failure Modes

| Failure | Guard |
|---|---|
| Hot wallet drained | Hard cap on the hot balance; on-chain outflow alerts |
| Insider approves own withdrawal | Requester and approver must differ; M-of-N |
| Attacker adds own address | Allow-list cooling-off period and notification |
| Key leaked through logs or a crash dump | No key material in process memory longer than needed; dumps disabled |
| Backups unrecoverable | Recovery rehearsed and dated |

## Verify Before Done

Never print secret values. These checks list file names or redact matches:

```bash
gitleaks detect --source . --redact --no-banner    # secrets in history, values redacted
# Key-like material in the tree: file names only; inspect each file without printing values
grep -rlE 'BEGIN (EC |RSA |OPENSSH )?PRIVATE KEY|xprv[0-9A-Za-z]{20,}|mnemonic|seed[_ ]?phrase' --exclude-dir=.git .
# Nothing key-like reaches logs
grep -rnE '(log|logger|console|print)[^;]*(private_?key|mnemonic|seed|secret)' <src>/
# Limits, cooling-off, M-of-N and requester != approver are tested
<test-cmd> -k 'withdrawal_policy or allowlist or approval'
```

---
name: kyc-aml-compliance
description: Builds and reviews identity verification and anti-money-laundering controls in product code - KYC tiers and limits, sanctions and PEP screening hook points, transaction monitoring, travel-rule data, PII minimisation and retention, and immutable audit logs. Use when implementing onboarding, verification levels, screening, monitoring rules, or code that stores or processes identity documents and personal data. Jurisdiction-specific rules, thresholds and lists come from the project, never from this skill.
---

# KYC and AML Compliance

## Overview

This skill covers how compliance controls are built, not which ones the law requires. The checks, limits,
thresholds, retention periods and reporting duties come from the project's compliance owner and the
jurisdictions it operates in. Encode them as versioned configuration with a named owner. If a requirement
is missing, ask; never invent a threshold.

## KYC Tiers

- A tier state machine (for example unverified, basic, full, enhanced), with limits per tier on deposits,
  withdrawals and trading per day and per month.
- Enforce limits on the server, at the action. A limit shown only in the UI is not a control.
- Record every tier change with the evidence references and the reviewer. Re-verification triggers
  (document expiry, a changed risk score) and downgrades are part of the machine.

## Screening Hook Points

- Screen at onboarding, on changes to name, date of birth, nationality or address, when a counterparty or
  beneficiary is added, before payouts and withdrawals, and across the whole customer base when the lists
  update.
- The screening provider sits behind an interface. Results: clear, potential match (manual review queue),
  confirmed match (freeze and escalate). Matching thresholds live in configuration.
- Fail closed: if screening is unavailable, hold the action. Never skip the check.

## Transaction Monitoring

- Rules over events: thresholds, velocity, structuring just below a threshold, rapid in-and-out, large
  volume on a new account, activity that does not fit the customer profile, risk factors from configuration.
- Alerts open cases with a state, an assignee, a deadline, notes and a recorded decision. Rules are
  versioned and backtested on historical data before they change.
- Do not tip off: the product never tells the customer why an account is under review. Reporting to
  authorities is a human decision recorded in the case.

## Travel Rule

- For transfers between virtual-asset service providers above the configured threshold, collect and send
  originator and beneficiary data over the configured protocol, and store it with the transfer.
- Handle transfers to and from self-hosted wallets as the policy requires; hold transfers whose required
  counterparty data is missing.

## PII Minimisation and Retention

- Collect only the fields the configured requirements need.
- Keep identity data in a separate store, encrypted at rest, with field-level encryption for document
  images and numbers and keys in a key management service. Access is by role and audited; other systems
  hold tokenised references.
- No PII in logs, analytics, error trackers, URLs or test fixtures; tests use synthetic identities.
- A retention schedule per data class comes from configuration. Deletion or anonymisation jobs record
  evidence; a legal hold overrides deletion. Data-subject requests have a tracked workflow.

## Audit Logs

- Append-only (write-once storage, or hash-chained records), covering every automated and manual decision:
  who, when, what, why, and the rule or model version.
- Verify the tamper evidence on a schedule; retain logs as configured.

## Verify Before Done

```bash
# Include a test that a screening outage holds the action (fail closed)
<test-cmd> -k 'kyc or screening or monitoring or retention or audit'
# PII must not reach logs or error trackers
grep -rniE '(log|logger|console|print|captureException)[^;]*(passport|national_?id|ssn|date_of_birth|\bdob\b|document_number)' <src>/
# Limits and thresholds belong in versioned config, not in code: review each hit
grep -rniE '(limit|threshold)[a-z_]*[[:space:]]*[:=][[:space:]]*[0-9]{3,}' <src>/
<audit-verify-cmd>   # the hash chain or write-once check of the audit log passes
```

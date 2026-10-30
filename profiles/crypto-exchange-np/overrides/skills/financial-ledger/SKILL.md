---
name: financial-ledger
description: Builds and reviews internal financial ledgers - double-entry journals, immutable entries, exact decimals with explicit rounding, idempotency keys, balances derived from entries, daily reconciliation and an audit trail. Use when writing or changing code that records money movements, balances, fees, holds or transfers between accounts. Not for reconciling on-chain balances against nodes or for compliance screening.
---

# Financial Ledger

## Overview

A ledger answers "where did every unit of money come from and go to" for any point in time, and it must
give the same answer tomorrow. That needs double entry, entries that never change, exact arithmetic, and a
reconciliation that proves the books match the outside world.

## Model

- **Accounts** have a type (asset, liability, equity, income, expense), a currency or asset, and an owner.
- **Journals**: one business event is one journal with two or more **postings**.
- **Postings** use a signed amount (debits positive, credits negative) or separate debit and credit
  columns. For every journal, the postings sum to zero per currency. Enforce it in the database (a
  constraint trigger, or a single insert function that validates the whole journal) as well as in code.

## Immutability

- Postings and journals are append-only: the application's database role has no UPDATE or DELETE on them,
  and a trigger rejects both.
- Corrections are a reversing journal plus a new journal, both linked to the original.
- Keep both the effective date and the recorded time. Closed periods accept no postings; late adjustments
  go into the open period with a reference to the original.

## Exact Amounts and Rounding

- Integers in each asset's minor units, the only form in this project (`SPEC.md`): `Amount(i128)` in Rust,
  `NUMERIC(39,0)` in Postgres (`BIGINT` only where the range provably fits), and decimal strings only at the
  API and display boundary. The scale per asset lives in `reference-data` (NPR 2; tokens up to 18). Never
  binary floating point or a decimal type with a fractional scale, anywhere in the money path, including
  JSON parsing.
- The rounding mode is explicit per operation (half-even, half-up or toward zero), applied once at the
  boundary. Book the rounding residue to a dedicated account instead of losing it.
- Currency conversion is two postings with the rate recorded, through a conversion account.

## Idempotency

- Every journal carries an idempotency key from its source event (a payment provider reference, a
  transaction hash and index, a request id), with a unique constraint.
- A retry returns the existing journal. The database enforces uniqueness; a read-then-insert check is a race.

## Balances

- Balances are derived from postings. A stored balance is a cache, updated in the same transaction as the
  postings, with a sequence number, and recomputed from postings on a schedule and compared.
- Available balance = ledger balance minus holds; holds are postings to a holds account, not a flag.
- Prevent negative balances inside the posting transaction: lock the account row (`SELECT ... FOR
  UPDATE`) or use serialisable isolation. Lock accounts in id order to avoid deadlocks, and retry
  serialisation failures with the same idempotency key.

## Reconciliation

- Daily: compare the ledger with every external source (bank statements, payment provider settlements,
  custodian balances): matched, unmatched on each side, and differences.
- Trial balance: all postings sum to zero per currency.
- Every difference goes to a suspense account with an owner and a deadline. Store the reconciliation
  results.

## Audit Trail

- Each journal records who or what created it, the source system, the request id and a reason code.
- Manual adjustments need two-person approval and are logged with both people.

## This Project

- Scales: NPR in paisa (scale 2); each crypto asset at the scale in the asset registry (for example 8 for
  BTC, 18 for ETH); perpetuals settle in their collateral asset.
- Every exchange flow is a journal: crypto and NPR deposits, withdrawals (hold, then settle or release),
  trade settlement (maker, taker and fee accounts), fees and maker rebates, funding payments, realised PnL,
  liquidation fees, the insurance fund and auto-deleveraging.
- Customer balances are liabilities backed by custodial assets: reconcile them daily per asset against the
  wallets (custody) and the bank accounts (NPR).
- Zero tolerance: an unexplained difference pauses withdrawals of that asset until it is resolved.
- The public testnet runs the same ledger code with test assets; its books never mix with prod.

## Verify Before Done

Replace the placeholders with the project's database and table names:

```bash
<test-cmd> -k 'ledger or journal or idempot or reconcil'
# Every journal balances per currency (expect 0 rows)
psql -d <ledger_db> -c "SELECT journal_id, currency FROM <postings> GROUP BY 1, 2 HAVING SUM(amount) <> 0;"
# Trial balance per currency (expect 0 rows)
psql -d <ledger_db> -c "SELECT currency FROM <postings> GROUP BY 1 HAVING SUM(amount) <> 0;"
# The application role cannot UPDATE or DELETE postings
psql -d <ledger_db> -c "\dp <postings>"
grep -rniE 'update[[:space:]]+<postings>|delete[[:space:]]+from[[:space:]]+<postings>' <src>/   # expect none
# Binary floating point in money code: each hit needs a reason
grep -rnE '\b(float|double|f32|f64|parseFloat)\b' <money-src>/
```

---
name: quant-researcher
description: Runs quantitative trading research so that results survive live markets - hypothesis first, point-in-time data with no lookahead or survivorship bias, out-of-sample and walk-forward validation, fees, slippage, funding and latency in every backtest, multiple-testing control, and reproducible runs (seeds, data versions). Use when designing, running or reviewing a backtest, a signal or factor study, or a strategy evaluation. Not for production trading code (quant-developer).
---

# Quant Researcher

## Overview

Most backtests are wrong in the same few ways: they use information that was not available at the time,
they ignore what trading costs, and they report the best of many tries as if it were the only one. This
skill is a set of rules that block those failures, and a log that makes each result reproducible.

## When to Use

- Testing a trading idea, signal, factor or parameter set on historical data.
- Reviewing someone else's backtest or research notebook.
- Deciding whether a strategy is ready to hand to production.

Not for: production execution, order or risk code.

## Rules

### 1. Hypothesis first

Before touching the data, write in the research log, with the date: the economic rationale, the expected
sign and rough size of the effect, the holding period, the universe, and the result that would falsify it.
A hypothesis written after seeing the data is a description of noise.

### 2. Point-in-time data only

Every value used at time t must have been available at t.

- Use the publication or knowledge timestamp, not the period it describes. Fundamentals and macro data
  arrive late and get revised; use the as-first-reported vintage.
- Universe as of each date: include delisted stocks, dead coins and tokens, expired contracts, and venues
  that shut down. A universe built from today's listings has survivorship bias.
- Corporate actions and index membership as known on the date, not as later restated.

Lookahead traps to search for:

| Pattern | Why it leaks |
|---|---|
| `shift(-n)` on a feature | Reads the future |
| `bfill` or back-filling gaps | Copies future values backwards |
| `rolling(..., center=True)` | The window includes future rows |
| Scaler, PCA or model fitted on the full sample | Test-period statistics leak into training |
| Trading at the close of the bar that produced the signal | The close was not known when deciding |
| Date joins without as-of logic | Use `merge_asof(direction="backward")` or equivalent |
| Entry and stop both inside one bar's high and low | The order of high and low inside the bar is unknown |

### 3. Out-of-sample and walk-forward

- Split by time, never shuffled. Add purging and an embargo between folds when labels span several bars.
- Walk forward: refit on a rolling or expanding window, test on the next period, report every fold.
- The final test set is used once. Looking at it twice makes it a validation set.

### 4. Costs in every backtest

- Fees per venue and tier (maker and taker), the spread, and slippage that scales with order size against
  traded volume or book depth.
- Market impact once size is material; report performance against notional (capacity).
- Funding for perpetuals, borrow cost for shorts, financing for leverage.
- Latency: a signal at t trades at t plus the realistic delay, at the price then.
- A strategy that only works at zero cost is not a result.

### 5. Multiple testing

- Log every variant tried: parameters, features, universes, periods. The count matters.
- Correct for it: deflated Sharpe ratio, White's reality check or Hansen's SPA test, or a false discovery
  rate on p-values.
- Prefer few parameters and a stable plateau of good values over a sharp optimum.

### 6. Report net of costs

Annualised return and volatility, Sharpe (state the annualisation factor: sqrt(252) for daily equities,
sqrt(365) for daily crypto), Sortino, maximum drawdown and its duration, turnover, hit rate, average win and
loss, exposure to the market, results per year and per regime, and confidence intervals from a block
bootstrap.

### 7. Reproducibility

Every result records: the code commit (from a clean tree), the data snapshot version or hash, the config
file, random seeds, and the locked environment. A rerun reproduces the numbers exactly, or within a stated
tolerance when parallel floating-point sums are involved.

## Red Flags

| Seen in the research | Problem |
|---|---|
| Sharpe above 3 on daily data | Usually leakage or missing costs; check before celebrating |
| Results only from one market regime | No evidence it survives the next one |
| "We tried a few settings" with no count | Unknown multiple-testing bias |
| Universe = current constituents | Survivorship bias |
| No cost model, or a flat 1 bp everywhere | Turnover-heavy strategies look good for free |
| Notebook state, not a script | Not reproducible |

## Verify Before Done

```bash
git status --porcelain              # expect empty: results come from committed code
git rev-parse HEAD                   # record in the result metadata
sha256sum data/<snapshot-files>     # or the project's data-versioning tool (e.g. dvc status)
# Lookahead patterns in feature code: each hit needs a written justification
grep -rnE 'shift\(-[0-9]+\)|bfill|fillna\(method=.?bfill|center=True' <research-src>/
# Same seed and data give the same result
<backtest-cmd> --seed 7 --out run1.json && <backtest-cmd> --seed 7 --out run2.json && diff run1.json run2.json
python -m pytest -q <research-tests>/
```

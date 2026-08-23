# 🗄️ SQL Overview

T-SQL scripts that take raw Synthea CSV exports to a validated, analytics-ready SQL Server database (`hospital_db`), then answer the project's three core analytics objectives. Dialect: **SQL Server / T-SQL**, written for SQL Server Management Studio (SSMS).

Read alongside [`../docs/data_quality_findings.md`](../docs/data_quality_findings.md), which explains the *why* behind every fix and interpretation decision made in these scripts.

---

## Run order

Run the scripts **in this order, one at a time** — several use `GO` batch separators and are not meant to be executed as a single blind block.

| # | Script | What it does |
|---|---|---|
| 1 | [`01_setup_sqlserver.sql`](01_setup_sqlserver.sql) | Drops/recreates `hospital_db`, creates all tables, and `BULK INSERT`s the 5 source CSVs. |
| 2 | [`02_data_quality_checks.sql`](02_data_quality_checks.sql) | Row counts, missing-value audit, referential-integrity checks, temporal/financial sanity checks. |
| 3 | [`03_data_fixes.sql`](03_data_fixes.sql) | Converts empty-string fields to real `NULL`s, repairs the one dropped patient record, adds FK constraints once integrity is confirmed. |
| 4 | [`04_analytics_objective1.sql`](04_analytics_objective1.sql) | **Objective 1 — Encounters Overview**: volume trends and encounter-class mix by year. |
| 5 | [`05_analytics_objective2.sql`](05_analytics_objective2.sql) | **Objective 2 — Cost & Coverage Insights**: zero-coverage analysis, payer breakdowns, cost-efficiency by encounter class. |
| 6 | [`06_analytics_objective3.sql`](06_analytics_objective3.sql) | **Objective 3 — Patient Behaviour Analysis**: quarterly unique patients, 30-day readmission (broad vs. strict definitions). |

---

## Before you run anything

1. **Get the data.** Source is [Synthea](https://synthetichealth.github.io/synthea/), a synthetic patient generator (100% synthetic — no real patient data). Export `patients.csv`, `encounters.csv`, `procedures.csv`, `payers.csv`, `organizations.csv`.
2. **Place the CSVs in `C:\HospitalData\`** (or edit the file paths at the top of `01_setup_sqlserver.sql`).
3. **Grant read access.** If `BULK INSERT` fails with "Access denied," right-click the folder → *Properties → Security* → grant `Everyone` Read permission.
4. **Check line endings.** `ROWTERMINATOR` is set to `0x0a` (LF only). If your CSVs use Windows `CRLF` line endings, a stray `\r` will silently get appended to the last column of every row. Either re-save the CSVs as LF, or change `ROWTERMINATOR` to `'\r\n'`.
5. **Run `01_setup_sqlserver.sql` in chunks**, not all at once — it's explicitly commented `DON'T RUN THIS ALL AT ONCE. IT WILL THROW ERROR!!!` because of the `GO` batch boundaries around the `DROP DATABASE` / `CREATE DATABASE` statements.

---

## Expected result after setup

| Table | Row count |
|---|---:|
| `patients` | 974 |
| `encounters` | 27,891 |
| `procedures` | 47,701 |
| `payers` | 10 |
| `organizations` | 1 |

If your counts don't match — especially `patients` landing on 973 instead of 974 — that's the exact quoted-field `BULK INSERT` issue documented in [`../docs/data_quality_findings.md`](../docs/data_quality_findings.md#issue-1-missing-patient-record-after-bulk-insert); running `03_data_fixes.sql` resolves it.

---

## Notable interpretation decisions baked into these scripts

These aren't bugs to "fix" — they're deliberate, documented choices (full rationale in the data-quality doc):

- **"Zero payer coverage"** is interpreted literally as `PAYER_COVERAGE = 0`, kept distinct from `PAYER = 'NO_INSURANCE'` (uninsured). Both are reported separately.
- **"Admitted each quarter"** counts *any* encounter, not just `ENCOUNTERCLASS = 'inpatient'`. The stricter inpatient-only version is left as a one-line comment swap in `06_analytics_objective3.sql`.
- **30-day readmission** is calculated two ways — a broad "any encounter within 30 days" definition (772 patients, ~79%) and a strict inpatient-to-inpatient definition (~29 patients) — because they answer genuinely different questions.

---

## Where this feeds into

- **Power BI** ([`../PowerBI`](../PowerBI)) connects directly to `hospital_db` for the 3-page dashboard.
- **The ML notebook** ([`../notebooks/readmission_model.ipynb`](../notebooks/readmission_model.ipynb)) pulls its training features from `hospital_db` via a single SQLAlchemy query using the same window-function patterns as `06_analytics_objective3.sql`.

---

<p align="center"><sub>Part of the <a href="../README.md">HospitalIQ</a> project.</sub></p>

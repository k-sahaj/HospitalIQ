/* ============================================================================
   05_analytics_objective2.sql
   ----------------------------------------------------------------------------
   Objective 2: Cost & Coverage Insights
   Dialect: SQL Server / T-SQL
   ============================================================================ */

SET NOCOUNT ON;
GO

USE hospital_db;
GO


-- ============================================================================
-- 2a. Encounters with zero payer coverage
-- ============================================================================
-- Interpretation: PAYER_COVERAGE = 0 (literal reading of "zero coverage").
-- See docs/data_quality_findings.md for the uninsured-vs-zero-coverage distinction.
SELECT
    SUM(CASE WHEN PAYER_COVERAGE = 0 THEN 1 ELSE 0 END)                      AS zero_coverage_encounters,
    COUNT(*)                                                                 AS total_encounters,
    CAST(100.0 * SUM(CASE WHEN PAYER_COVERAGE = 0 THEN 1 ELSE 0 END)
         / COUNT(*) AS DECIMAL(5,2))                                         AS pct_zero_coverage
FROM   encounters;

/* Result: 13,586 of 27,891 (48.71%) had zero payer coverage. */


-- ============================================================================
-- 2a (bonus). Zero-coverage encounters broken down by payer
-- ============================================================================
-- Surfaces the key nuance: 4,779 zero-coverage encounters belong to insured
-- patients (likely deductibles or denied claims), not uninsured.
SELECT
    p.NAME                                                                   AS payer,
    COUNT(*)                                                                 AS zero_coverage_encounters
FROM   encounters e
JOIN   payers     p ON e.PAYER = p.Id
WHERE  e.PAYER_COVERAGE = 0
GROUP BY p.NAME
ORDER BY zero_coverage_encounters DESC;

/* Result:
   NO_INSURANCE              8,807
   Humana                    1,038
   Aetna                       898
   UnitedHealthcare            820
   Cigna Health                790
   Anthem                      704
   Blue Cross Blue Shield      336
   Dual Eligible                127
   Medicare                     61
   Medicaid                       5

   Key insight: 35% of zero-coverage encounters belong to patients with
   active insurance - consistent with high-deductible plans or denied claims. */


-- ============================================================================
-- 2b. Top 10 most frequent procedures, with average base cost
-- ============================================================================
SELECT TOP 10
    CODE                                                                     AS snomed_code,
    DESCRIPTION                                                              AS procedure_name,
    COUNT(*)                                                                 AS times_performed,
    CAST(AVG(BASE_COST) AS DECIMAL(10,2))                                    AS avg_base_cost
FROM   [procedures]
GROUP BY CODE, DESCRIPTION
ORDER BY times_performed DESC;

/* Notable: 8 of top 10 procedures share a flat $431 base cost (Synthea
   uses a fixed rate for routine assessments). Renal dialysis (#6) at
   $1,004 and Medication Reconciliation (#9) at $509 are the cost outliers. */


-- ============================================================================
-- 2c. Top 10 procedures with highest average base cost
-- ============================================================================
SELECT TOP 10
    CODE                                                                     AS snomed_code,
    DESCRIPTION                                                              AS procedure_name,
    CAST(AVG(BASE_COST) AS DECIMAL(12,2))                                    AS avg_base_cost,
    COUNT(*)                                                                 AS times_performed
FROM   [procedures]
GROUP BY CODE, DESCRIPTION
ORDER BY AVG(BASE_COST) DESC;

/* Cost driver insights:
   - ICU admit: $206,260 avg, only 5 occurrences = ~$1M total
   - Electrical cardioversion: $25,903 x 1,383 = ~$35.8M total
     (the single biggest cost driver in the dataset by volume x cost) */


-- ============================================================================
-- 2d. Average total claim cost per encounter, by payer
-- ============================================================================
SELECT
    p.NAME                                                                   AS payer,
    COUNT(*)                                                                 AS encounters,
    CAST(AVG(e.TOTAL_CLAIM_COST) AS DECIMAL(10,2))                           AS avg_total_claim_cost
FROM   encounters e
JOIN   payers     p ON e.PAYER = p.Id
GROUP BY p.NAME
ORDER BY avg_total_claim_cost DESC;

/* Key finding: average claim cost varies 3.7x across payers ($1,696 to $6,205).
   Medicaid ($6,205) and uninsured ($5,593) encounters have the highest
   average costs - consistent with delayed-care patterns in US healthcare.
   Medicare has the lowest average ($2,167) despite the largest volume
   (11,371 encounters / 41% of all), reflecting reimbursement caps. */

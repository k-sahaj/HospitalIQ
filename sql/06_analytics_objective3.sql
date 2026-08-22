/* ============================================================================
   06_analytics_objective3.sql
   ----------------------------------------------------------------------------
   Objective 3: Patient Behaviour Analysis
   Dialect: SQL Server / T-SQL
   ============================================================================ */

SET NOCOUNT ON;
GO

USE hospital_db;
GO


-- ============================================================================
-- 3a. Unique patients admitted each quarter
-- ============================================================================
-- "Admitted" interpreted broadly as any encounter. For inpatient-only,
-- add: WHERE ENCOUNTERCLASS = 'inpatient' before GROUP BY.
SELECT
    YEAR(START)                                                              AS year,
    DATEPART(QUARTER, START)                                                 AS quarter,
    COUNT(DISTINCT PATIENT)                                                  AS unique_patients
FROM   encounters
GROUP BY YEAR(START), DATEPART(QUARTER, START)
ORDER BY year, quarter;

/* Result: 45 quarters (2011-Q1 to 2022-Q1). Stable around 240 patients
   most quarters, with surges in 2014-Q1 (394) and 2021-Q1/Q2 (417, 414).
   Both surge periods correlate with overall encounter peaks - indicating
   new-patient growth events rather than higher utilisation. */


-- ============================================================================
-- 3b. Patients readmitted within 30 days of a previous encounter
-- ============================================================================
-- Broad definition: any encounter within 30 days of any prior encounter.
WITH ordered_encounters AS (
    SELECT
        PATIENT,
        START,
        STOP,
        LAG(STOP) OVER (PARTITION BY PATIENT ORDER BY START)                 AS prev_stop
    FROM encounters
)
SELECT
    COUNT(DISTINCT PATIENT)                                                  AS patients_readmitted_30d
FROM   ordered_encounters
WHERE  prev_stop IS NOT NULL
  AND  DATEDIFF(DAY, prev_stop, START) BETWEEN 0 AND 30;

/* Result: 772 distinct patients (79.3% of 974) had an encounter within
   30 days of a prior one. Note: this broad definition counts two routine
   ambulatory visits 3 weeks apart as a "readmission". See strict variant
   below for CMS-aligned definition. */


-- ============================================================================
-- 3b strict. Inpatient-to-inpatient readmissions only (CMS-aligned)
-- ============================================================================
WITH ordered_inpatient AS (
    SELECT
        PATIENT,
        START,
        STOP,
        LAG(STOP) OVER (PARTITION BY PATIENT ORDER BY START)                 AS prev_stop
    FROM   encounters
    WHERE  ENCOUNTERCLASS = 'inpatient'
)
SELECT
    COUNT(DISTINCT PATIENT)                                                  AS patients_readmitted_30d_inpatient
FROM   ordered_inpatient
WHERE  prev_stop IS NOT NULL
  AND  DATEDIFF(DAY, prev_stop, START) BETWEEN 0 AND 30;

/* Result: ~29 patients under the strict clinical definition. The 26x
   difference between broad (772) and strict (29) shows how much the
   definition shapes the answer - worth flagging to any business stakeholder. */


-- ============================================================================
-- 3c. Top 10 patients with the most readmissions
-- ============================================================================
WITH ordered_encounters AS (
    SELECT
        PATIENT,
        START,
        STOP,
        LAG(STOP) OVER (PARTITION BY PATIENT ORDER BY START)                 AS prev_stop
    FROM encounters
),
readmissions AS (
    SELECT
        PATIENT,
        COUNT(*)                                                             AS readmissions
    FROM   ordered_encounters
    WHERE  prev_stop IS NOT NULL
      AND  DATEDIFF(DAY, prev_stop, START) BETWEEN 0 AND 30
    GROUP BY PATIENT
)
SELECT TOP 10
    r.PATIENT                                                                AS patient_id,
    p.FIRST + ' ' + p.LAST                                                   AS patient_name,
    r.readmissions
FROM   readmissions r
JOIN   patients     p ON r.PATIENT = p.Id
ORDER BY r.readmissions DESC;

/* Result (top 3):
   Kimberly627 Collier206       1,376
   Mariano761 O'Kon634            876
   Shani239 Parisian75            871

   Caveat documented in docs/data_quality_findings.md: Kimberly627 has 1,381
   lifetime encounters, almost entirely ambulatory - a chronic-care
   profile, not acute readmissions. Any "top readmitters" dashboard
   should either filter her or split ambulatory from acute encounters. */

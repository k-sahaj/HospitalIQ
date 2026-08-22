/* ============================================================================
   04_analytics_objective1.sql
   ----------------------------------------------------------------------------
   Objective 1: Encounters Overview
   Dialect: SQL Server / T-SQL
   ============================================================================ */

SET NOCOUNT ON;
GO

USE hospital_db;
GO


-- ============================================================================
-- 1a. Total encounters per year
-- ============================================================================
SELECT
    YEAR(START)   AS year,
    COUNT(*)      AS total_encounters
FROM   encounters
GROUP BY YEAR(START)
ORDER BY year;

/* Result: 12 years (2011-2022). Peaks: 2014 (3,885), 2021 (3,530).
   2022 partial (220 - data ends 5 Feb 2022). Total: 27,891. */


-- ============================================================================
-- 1b. Percentage share of each encounter class per year
-- ============================================================================
SELECT
    YEAR(START)                                                              AS year,
    ENCOUNTERCLASS                                                           AS encounter_class,
    COUNT(*)                                                                 AS encounters,
    CAST(100.0 * COUNT(*)
         / SUM(COUNT(*)) OVER (PARTITION BY YEAR(START)) AS DECIMAL(5,2))    AS pct_of_year
FROM   encounters
GROUP BY YEAR(START), ENCOUNTERCLASS
ORDER BY year, encounter_class;

/* Notable finding: In 2021 outpatient share surged to 40.17% (1,418 encounters,
   up from ~480 in prior years) while ambulatory dropped to 36.91% - the only
   year ambulatory was not the dominant class. Likely a COVID-era coding
   reclassification or operational change. Worth flagging to ops team. */


-- ============================================================================
-- 1c. Percentage of encounters over vs. under 24 hours
-- ============================================================================
SELECT
    CASE
        WHEN DATEDIFF(MINUTE, START, STOP) >= 24*60 THEN 'Over 24 hours'
        ELSE 'Under 24 hours'
    END                                                                      AS duration_bucket,
    COUNT(*)                                                                 AS encounters,
    CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS DECIMAL(5,2))           AS pct_of_all
FROM   encounters
GROUP BY
    CASE
        WHEN DATEDIFF(MINUTE, START, STOP) >= 24*60 THEN 'Over 24 hours'
        ELSE 'Under 24 hours'
    END;

/* Result:
   Under 24 hours = 26,739 (95.87%)
   Over  24 hours =  1,152 ( 4.13%) */

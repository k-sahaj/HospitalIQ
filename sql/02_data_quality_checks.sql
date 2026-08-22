/* ============================================================================
   02_data_quality_checks.sql
   ----------------------------------------------------------------------------
   Comprehensive data quality audit. Run after 01_setup_sqlserver.sql.
   See docs/data_quality_findings.md for documented findings and decisions.
   ============================================================================ */

SET NOCOUNT ON;
GO

USE hospital_db;
GO


-- ============================================================================
-- 1. ROW COUNTS — confirm the load worked
-- ============================================================================
SELECT 'patients'      AS table_name, COUNT(*) AS row_count FROM patients
UNION ALL SELECT 'encounters',     COUNT(*) FROM encounters
UNION ALL SELECT 'procedures',     COUNT(*) FROM [procedures]
UNION ALL SELECT 'payers',         COUNT(*) FROM payers
UNION ALL SELECT 'organizations',  COUNT(*) FROM organizations;
-- Expected: 974 / 27,891 / 47,701 / 10 / 1


-- ============================================================================
-- 2. MISSING VALUES — encounters
-- ============================================================================
SELECT
    SUM(CASE WHEN PATIENT          IS NULL THEN 1 ELSE 0 END) AS null_patient,
    SUM(CASE WHEN PAYER            IS NULL THEN 1 ELSE 0 END) AS null_payer,
    SUM(CASE WHEN ENCOUNTERCLASS   IS NULL THEN 1 ELSE 0 END) AS null_class,
    SUM(CASE WHEN STOP             IS NULL THEN 1 ELSE 0 END) AS null_stop,
    SUM(CASE WHEN PAYER_COVERAGE   IS NULL THEN 1 ELSE 0 END) AS null_coverage,
    SUM(CASE WHEN TOTAL_CLAIM_COST IS NULL THEN 1 ELSE 0 END) AS null_total_cost,
    SUM(CASE WHEN REASONCODE       IS NULL THEN 1 ELSE 0 END) AS null_reasoncode,
    COUNT(*)                                                   AS total_rows
FROM encounters;
-- Expected after fixes: REASONCODE ~70% null (normal - routine visits have no diagnosis)


-- ============================================================================
-- 3. MISSING VALUES — patients
-- ============================================================================
SELECT
    SUM(CASE WHEN BIRTHDATE IS NULL THEN 1 ELSE 0 END) AS null_birthdate,
    SUM(CASE WHEN DEATHDATE IS NULL THEN 1 ELSE 0 END) AS null_deathdate,
    SUM(CASE WHEN GENDER    IS NULL THEN 1 ELSE 0 END) AS null_gender,
    SUM(CASE WHEN ZIP       IS NULL THEN 1 ELSE 0 END) AS null_zip,
    SUM(CASE WHEN MARITAL   IS NULL THEN 1 ELSE 0 END) AS null_marital,
    COUNT(*)                                            AS total_rows
FROM patients;
-- Expected after fixes: ~154 with deathdate, ~142 null zip, 1 null marital


-- ============================================================================
-- 4. MISSING VALUES — procedures
-- ============================================================================
SELECT
    SUM(CASE WHEN PATIENT    IS NULL THEN 1 ELSE 0 END) AS null_patient,
    SUM(CASE WHEN ENCOUNTER  IS NULL THEN 1 ELSE 0 END) AS null_encounter,
    SUM(CASE WHEN CODE       IS NULL THEN 1 ELSE 0 END) AS null_code,
    SUM(CASE WHEN BASE_COST  IS NULL THEN 1 ELSE 0 END) AS null_base_cost,
    SUM(CASE WHEN REASONCODE IS NULL THEN 1 ELSE 0 END) AS null_reasoncode,
    COUNT(*)                                             AS total_rows
FROM [procedures];


-- ============================================================================
-- 5. DUPLICATE PRIMARY KEYS — should all be zero
-- ============================================================================
SELECT 'encounters' AS table_name, COUNT(*) AS duplicate_ids
FROM (SELECT Id FROM encounters GROUP BY Id HAVING COUNT(*) > 1) d
UNION ALL
SELECT 'patients', COUNT(*)
FROM (SELECT Id FROM patients GROUP BY Id HAVING COUNT(*) > 1) d
UNION ALL
SELECT 'payers', COUNT(*)
FROM (SELECT Id FROM payers GROUP BY Id HAVING COUNT(*) > 1) d;


-- ============================================================================
-- 6. DUPLICATE PROCEDURE ROWS (procedures has no natural PK)
-- ============================================================================
SELECT COUNT(*) AS duplicate_procedure_rows
FROM (
    SELECT START, STOP, PATIENT, ENCOUNTER, CODE, COUNT(*) AS c
    FROM [procedures]
    GROUP BY START, STOP, PATIENT, ENCOUNTER, CODE
    HAVING COUNT(*) > 1
) d;


-- ============================================================================
-- 7. ORPHAN FOREIGN KEYS — should all be zero after fixes
-- ============================================================================
SELECT 'enc.PATIENT orphans' AS check_name, COUNT(*) AS bad_rows
FROM encounters e LEFT JOIN patients p ON e.PATIENT = p.Id
WHERE p.Id IS NULL
UNION ALL
SELECT 'enc.PAYER orphans', COUNT(*)
FROM encounters e LEFT JOIN payers p ON e.PAYER = p.Id
WHERE p.Id IS NULL
UNION ALL
SELECT 'enc.ORG orphans', COUNT(*)
FROM encounters e LEFT JOIN organizations o ON e.ORGANIZATION = o.Id
WHERE o.Id IS NULL
UNION ALL
SELECT 'proc.PATIENT orphans', COUNT(*)
FROM [procedures] pr LEFT JOIN patients p ON pr.PATIENT = p.Id
WHERE p.Id IS NULL
UNION ALL
SELECT 'proc.ENCOUNTER orphans', COUNT(*)
FROM [procedures] pr LEFT JOIN encounters e ON pr.ENCOUNTER = e.Id
WHERE e.Id IS NULL;


-- ============================================================================
-- 8. LOGICAL INTEGRITY — date and value sanity
-- ============================================================================
SELECT 'enc STOP < START' AS check_name, COUNT(*) AS bad_rows
FROM encounters WHERE STOP < START
UNION ALL
SELECT 'proc STOP < START', COUNT(*)
FROM [procedures] WHERE STOP < START
UNION ALL
SELECT 'negative encounter costs', COUNT(*)
FROM encounters
WHERE BASE_ENCOUNTER_COST < 0 OR TOTAL_CLAIM_COST < 0 OR PAYER_COVERAGE < 0
UNION ALL
SELECT 'coverage > total claim', COUNT(*)
FROM encounters WHERE PAYER_COVERAGE > TOTAL_CLAIM_COST
UNION ALL
SELECT 'death before birth', COUNT(*)
FROM patients WHERE DEATHDATE IS NOT NULL AND DEATHDATE < BIRTHDATE;


-- ============================================================================
-- 9. ENCOUNTERS AFTER PATIENT'S DEATH DATE
-- ============================================================================
-- Documented finding: ~53 such encounters. Likely admin/billing entries.
-- Decision: keep for cost analysis, exclude from patient behaviour analysis.
SELECT COUNT(*) AS encounters_after_death
FROM encounters e
JOIN patients   p ON e.PATIENT = p.Id
WHERE p.DEATHDATE IS NOT NULL
  AND CAST(e.START AS DATE) > p.DEATHDATE;


-- ============================================================================
-- 10. OUTLIER PATIENTS — top encounter counts
-- ============================================================================
-- Documented finding: Kimberly627 Collier206 has 1,381 lifetime encounters
-- (mostly ambulatory). Chronic-care profile, not a data error.
SELECT TOP 10
    p.Id,
    p.FIRST + ' ' + p.LAST AS patient,
    COUNT(*) AS encounter_count
FROM encounters e
JOIN patients   p ON e.PATIENT = p.Id
GROUP BY p.Id, p.FIRST, p.LAST
ORDER BY encounter_count DESC;

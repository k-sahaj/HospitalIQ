/* ============================================================================
   03_data_fixes.sql
   ----------------------------------------------------------------------------
   Fixes applied after the initial BULK INSERT in 01_setup_sqlserver.sql.

   THREE THINGS HANDLED HERE:
   1. Empty CSV fields loaded as empty strings instead of NULLs.
   2. One patient row that failed to load (Mrs. Melaine933 Hintz995).
   3. (Optional) Foreign-key constraints, added only after the fixes above
      guarantee there are no orphan rows left to violate them.

   See docs/data_quality_findings.md for full context and decisions.
   ============================================================================ */

SET NOCOUNT ON;
GO

USE hospital_db;
GO


-- ============================================================================
-- FIX 1: Convert empty strings to proper NULLs
-- ============================================================================
-- BULK INSERT with FORMAT='CSV' loads empty fields as '' instead of NULL.
-- This UPDATE corrects it so date and string columns behave correctly in
-- downstream queries.

-- patients
UPDATE patients SET DEATHDATE = NULL WHERE DEATHDATE = '';
UPDATE patients SET ZIP       = NULL WHERE ZIP = '';
UPDATE patients SET MARITAL   = NULL WHERE MARITAL = '';
UPDATE patients SET PREFIX    = NULL WHERE PREFIX = '';
UPDATE patients SET SUFFIX    = NULL WHERE SUFFIX = '';
UPDATE patients SET MAIDEN    = NULL WHERE MAIDEN = '';

-- encounters
UPDATE encounters SET REASONCODE        = NULL WHERE REASONCODE = '';
UPDATE encounters SET REASONDESCRIPTION = NULL WHERE REASONDESCRIPTION = '';

-- procedures
UPDATE [procedures] SET REASONCODE        = NULL WHERE REASONCODE = '';
UPDATE [procedures] SET REASONDESCRIPTION = NULL WHERE REASONDESCRIPTION = '';
GO


-- ============================================================================
-- FIX 2: Reload the missing patient row
-- ============================================================================
-- BULK INSERT failed on patient 204f8028-72f8-d6f8-761f-79ebf9f02311
-- (Mrs. Melaine933 Hintz995), likely due to special characters in a quoted
-- field. The fix is to use SSMS's Import Flat File Wizard, which handles
-- quoted CSV fields more robustly than BULK INSERT.
--
-- STEPS (perform manually in SSMS UI):
--   1. Verify the row is missing:
--        SELECT COUNT(*) FROM patients;  -- if 973, run the import.
--   2. Object Explorer -> right-click hospital_db -> Tasks -> Import Flat File...
--   3. Select C:\HospitalData\patients.csv
--   4. New table name: patients_temp
--   5. Modify Columns step:
--        - Change BIRTHDATE  data type to nvarchar(50)
--        - Change DEATHDATE  data type to nvarchar(50)
--        - Change ZIP        data type to nvarchar(10)
--        Tick "Allow Nulls" for DEATHDATE, SUFFIX, MAIDEN, MARITAL, ZIP
--   6. Click Next -> Finish. Confirm "974 rows transferred".
--   7. Run the SQL below to merge into the main patients table.

-- Verify the temp table has the missing patient
-- (uncomment to run; skip if you didn't need the import)
/*
SELECT COUNT(*) AS total_in_temp FROM patients_temp;
-- Expected: 974

SELECT * FROM patients_temp
WHERE Id = '204f8028-72f8-d6f8-761f-79ebf9f02311';
-- Expected: 1 row, Mrs. Melaine933 Hintz995

-- Wipe the partially-loaded patients table
DELETE FROM patients;

-- Re-insert from temp, with proper NULL handling and date conversion
INSERT INTO patients (
    Id, BIRTHDATE, DEATHDATE, PREFIX, FIRST, LAST, SUFFIX, MAIDEN,
    MARITAL, RACE, ETHNICITY, GENDER, BIRTHPLACE, ADDRESS, CITY,
    STATE, COUNTY, ZIP, LAT, LON
)
SELECT
    Id,
    TRY_CAST(NULLIF(BIRTHDATE, '') AS DATE),
    TRY_CAST(NULLIF(DEATHDATE, '') AS DATE),
    NULLIF(PREFIX, ''),
    FIRST,
    LAST,
    NULLIF(SUFFIX, ''),
    NULLIF(MAIDEN, ''),
    NULLIF(MARITAL, ''),
    RACE,
    ETHNICITY,
    GENDER,
    BIRTHPLACE,
    ADDRESS,
    CITY,
    STATE,
    COUNTY,
    NULLIF(ZIP, ''),
    LAT,
    LON
FROM patients_temp;

-- Clean up
DROP TABLE patients_temp;
*/


-- ============================================================================
-- VERIFICATION
-- ============================================================================
SELECT
    COUNT(*)                                                AS total_patients,
    SUM(CASE WHEN DEATHDATE IS NOT NULL THEN 1 ELSE 0 END)  AS with_deathdate,
    SUM(CASE WHEN ZIP       IS NULL THEN 1 ELSE 0 END)      AS missing_zip,
    SUM(CASE WHEN MARITAL   IS NULL THEN 1 ELSE 0 END)      AS missing_marital
FROM patients;
-- Expected: 974 / 154 / 142 / 1

-- Confirm no orphan encounters remain
SELECT COUNT(*) AS missing_patient_encounters
FROM encounters e
LEFT JOIN patients p ON e.PATIENT = p.Id
WHERE p.Id IS NULL;
-- Expected: 0
GO


-- ============================================================================
-- FIX 3 (OPTIONAL): Enforce referential integrity going forward
-- ============================================================================
-- The base schema in 01_setup_sqlserver.sql intentionally omits FOREIGN KEY
-- constraints so the initial BULK INSERT can't be blocked by the one known
-- orphan row (see FIX 2). Once the counts above confirm zero orphans, adding
-- these constraints turns the manual checks in 02_data_quality_checks.sql
-- into guarantees enforced by the engine for any future data loads.
--
-- Uncomment to apply. PAYER and ORGANIZATION are nullable in the source data
-- (a handful of encounters have no payer on file), so those FKs are added
-- without NOT NULL.
/*
ALTER TABLE encounters
    ADD CONSTRAINT FK_encounters_patient      FOREIGN KEY (PATIENT)      REFERENCES patients(Id);
ALTER TABLE encounters
    ADD CONSTRAINT FK_encounters_payer        FOREIGN KEY (PAYER)        REFERENCES payers(Id);
ALTER TABLE encounters
    ADD CONSTRAINT FK_encounters_organization FOREIGN KEY (ORGANIZATION) REFERENCES organizations(Id);
ALTER TABLE [procedures]
    ADD CONSTRAINT FK_procedures_patient      FOREIGN KEY (PATIENT)      REFERENCES patients(Id);
ALTER TABLE [procedures]
    ADD CONSTRAINT FK_procedures_encounter    FOREIGN KEY (ENCOUNTER)    REFERENCES encounters(Id);
*/

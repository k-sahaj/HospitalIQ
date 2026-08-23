/* ============================================================================
   01_setup_sqlserver.sql
   ----------------------------------------------------------------------------
   DON'T RUN THIS ALL AT ONCE. IT WILL THROW ERROR!!!
   
   Creates the hospital_db database, all tables, and loads data from CSV files.
   Dialect: SQL Server / T-SQL (run in SSMS).

   DATA SOURCE: Synthea synthetic patient generator (100% synthetic — no real
   patient data). https://synthetichealth.github.io/synthea/

   BEFORE RUNNING:
   1. Place the 5 CSV files in C:\HospitalData\
        encounters.csv, patients.csv, procedures.csv, payers.csv, organizations.csv
   2. The SQL Server service account needs read permission on that folder.
      Easiest fix if BULK INSERT fails with "Access denied":
        Right-click C:\HospitalData -> Properties -> Security -> grant
        "Everyone" Read permission.
   3. Confirm the CSVs use LF (Unix) line endings. ROWTERMINATOR below is set
      to 0x0a (LF only). If the files are CRLF, the trailing \r will be
      silently appended to the last column of every row (REASONDESCRIPTION /
      LON) and show up later as a subtle data-quality issue. Re-save as LF,
      or change ROWTERMINATOR to '\r\n' if your source files are CRLF.

   RUN ORDER: 01 -> 02 -> 03 -> 04 -> 05 -> 06
   ============================================================================ */

SET NOCOUNT ON;
GO

USE master;
GO

-- Drop and recreate the database to ensure a clean, repeatable state
IF DB_ID('hospital_db') IS NOT NULL
BEGIN
    ALTER DATABASE hospital_db SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE hospital_db;
END
GO

CREATE DATABASE hospital_db;
GO

USE hospital_db;
GO


/* THERE ARE TWO APPROACHES HERE:
 1. CREATE TABLES AND THEN BULK INSERT FROM LOCALLY STORED CSV
 2. MANUALLY IMPORT THOSE CSV FILES USING FLAT FILE IMPORT

 Option 1 is not working because of the formatting issue.
 Thus, to generalize this and make this more reproducible, i have decided to opt
 the second approach. You should too. 

 - Right click on hospital_db -> Tasks -> Import flat file -> Browse -> do the essentials.
 - Once the files are imported, we are done.
 */

-- ============================================================================
-- INDEXES FOR QUERY PERFORMANCE
-- ============================================================================
-- Created after the bulk load (cheaper than maintaining them row-by-row
-- during insert).
CREATE INDEX idx_enc_patient ON encounters(PATIENT);
CREATE INDEX idx_enc_payer   ON encounters(PAYER);
CREATE INDEX idx_enc_start   ON encounters(START);
CREATE INDEX idx_proc_enc    ON [procedures](ENCOUNTER);
CREATE INDEX idx_proc_code   ON [procedures](CODE);
GO


-- ============================================================================
-- VERIFY THE LOAD
-- ============================================================================
SELECT 'patients'      AS table_name, COUNT(*) AS row_count FROM patients
UNION ALL SELECT 'encounters',     COUNT(*) FROM encounters
UNION ALL SELECT 'procedures',     COUNT(*) FROM [procedures]
UNION ALL SELECT 'payers',         COUNT(*) FROM payers
UNION ALL SELECT 'organizations',  COUNT(*) FROM organizations;

-- Expected: 974 / 27,891 / 47,701 / 10 / 1
-- If patients = 973, see 03_data_fixes.sql for the missing-patient reload.


/* If still you think the normal approach can work, you're free to experiment:
(just change the file location with your own)

-- ============================================================================
-- TABLE DEFINITIONS
-- ============================================================================

CREATE TABLE payers (
    Id                   CHAR(36)      PRIMARY KEY,
    NAME                 VARCHAR(100),
    ADDRESS              VARCHAR(255),
    CITY                 VARCHAR(100),
    STATE_HEADQUARTERED  CHAR(2),
    ZIP                  VARCHAR(10),
    PHONE                VARCHAR(20)
);

CREATE TABLE organizations (
    Id       CHAR(36)      PRIMARY KEY,
    NAME     VARCHAR(255),
    ADDRESS  VARCHAR(255),
    CITY     VARCHAR(100),
    STATE    CHAR(2),
    ZIP      VARCHAR(10),
    LAT      FLOAT,
    LON      FLOAT
);

CREATE TABLE patients (
    Id           CHAR(36)     PRIMARY KEY,
    BIRTHDATE    DATE,
    DEATHDATE    DATE,
    PREFIX       VARCHAR(10),
    FIRST        VARCHAR(100),
    LAST         VARCHAR(100),
    SUFFIX       VARCHAR(10),
    MAIDEN       VARCHAR(100),
    MARITAL      CHAR(1),
    RACE         VARCHAR(50),
    ETHNICITY    VARCHAR(50),
    GENDER       CHAR(1),
    BIRTHPLACE   VARCHAR(255),
    ADDRESS      VARCHAR(255),
    CITY         VARCHAR(100),
    STATE        VARCHAR(100),
    COUNTY       VARCHAR(100),
    ZIP          VARCHAR(10),
    LAT          FLOAT,
    LON          FLOAT
);

CREATE TABLE encounters (
    Id                    CHAR(36)       PRIMARY KEY,
    START                 DATETIME2,
    STOP                  DATETIME2,
    PATIENT               CHAR(36)       NOT NULL,
    ORGANIZATION          CHAR(36),
    PAYER                 CHAR(36),
    ENCOUNTERCLASS        VARCHAR(20),
    CODE                  VARCHAR(20),
    DESCRIPTION           VARCHAR(255),
    BASE_ENCOUNTER_COST   DECIMAL(12,2),
    TOTAL_CLAIM_COST      DECIMAL(12,2),
    PAYER_COVERAGE        DECIMAL(12,2),
    REASONCODE            VARCHAR(20),
    REASONDESCRIPTION     VARCHAR(255)
);

-- Bracketed: PROCEDURE is a T-SQL reserved word, and the plural form is
-- close enough to trip up tooling / future refactors, so we quote it
-- consistently everywhere it's referenced.
CREATE TABLE [procedures] (
    START              DATETIME2,
    STOP               DATETIME2,
    PATIENT            CHAR(36),
    ENCOUNTER          CHAR(36),
    CODE               VARCHAR(50),
    DESCRIPTION        VARCHAR(255),
    BASE_COST          DECIMAL(12,2),
    REASONCODE         VARCHAR(20),
    REASONDESCRIPTION  VARCHAR(255)
);
GO


-- ============================================================================
-- BULK LOAD DATA FROM CSV
-- ============================================================================
-- IMPORTANT: update the path if your CSVs live elsewhere.
--
-- KNOWN ISSUE (documented in docs/data_quality_findings.md):
-- BULK INSERT may fail to load one patient row (Mrs. Melaine933 Hintz995,
-- ID 204f8028-72f8-d6f8-761f-79ebf9f02311) due to special characters in the
-- quoted address field. If that happens, use the Import Flat File Wizard
-- as documented in 03_data_fixes.sql.
--
-- BULK INSERT also loads empty CSV fields as empty strings instead of NULLs.
-- This is corrected in 03_data_fixes.sql.

BULK INSERT payers
FROM 'C:\local disk C files\OneDrive\Desktop\PPrep\DS\Data_Analyst_Projects\HospitalIQ\dataset\payers.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    CODEPAGE = '65001',
    FORMAT = 'CSV',
    KEEPNULLS
);

BULK INSERT organizations
FROM 'C:\local disk C files\OneDrive\Desktop\PPrep\DS\Data_Analyst_Projects\HospitalIQ\dataset\organizations.csv'
WITH (
    FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0a',
    CODEPAGE = '65001', FORMAT = 'CSV', KEEPNULLS
);

BULK INSERT patients
FROM 'C:\local disk C files\OneDrive\Desktop\PPrep\DS\Data_Analyst_Projects\HospitalIQ\dataset\patients.csv'
WITH (
    FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0a',
    CODEPAGE = '65001', FORMAT = 'CSV', KEEPNULLS
);

BULK INSERT encounters
FROM 'C:\local disk C files\OneDrive\Desktop\PPrep\DS\Data_Analyst_Projects\HospitalIQ\dataset\encounters.csv'
WITH (
    FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0a',
    CODEPAGE = '65001', FORMAT = 'CSV', KEEPNULLS
);

BULK INSERT [procedures]
FROM 'C:\local disk C files\OneDrive\Desktop\PPrep\DS\Data_Analyst_Projects\HospitalIQ\dataset\procedures.csv'
WITH (
    FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0a',
    CODEPAGE = '65001', FORMAT = 'CSV', KEEPNULLS
);
GO

*/
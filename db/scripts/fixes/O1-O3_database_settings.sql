-- O1-O3_database_settings.sql
-- Database settings, in two steps run a few days apart. Set @Step at the top, run on staging, then production.
--   sqlcmd -S .\DEVELOPMENT -d Fitness -E -I -b -i fixes\O1-O3_database_settings.sql
--
-- @Step = 1  (O3) Turn on Query Store, so there is a plan history to compare against before the compatibility change.
--            Then use the API normally for a few days.
-- @Step = 2  (O1) Compatibility level 100 (SQL Server 2008) -> 170 (SQL Server 2025).
--            (O2) Database defaults QUOTED_IDENTIFIER, ANSI_NULLS and ANSI_PADDING ON (they only affect objects created
--            from now on), and a list of modules still created with QUOTED_IDENTIFIER OFF. The revised views, the fixed
--            functions and GetLastEntries were all created with it ON (sqlcmd -I); anything listed is either archived
--            (dropped after the quarantine) or should be recreated by republishing the SQL project.
--            Also set <CompatibilityMode>170</CompatibilityMode> in Fitness.sqlproj after this step.
-- Undo step 2 if something regresses:  ALTER DATABASE CURRENT SET COMPATIBILITY_LEVEL = 100;
--            or force the old plan for the one query in Query Store (SSMS: Query Store > Regressed Queries).
SET NOCOUNT ON;

DECLARE @Step tinyint = 1;   -- 1 = Query Store, 2 = compatibility level and settings

DECLARE @CurrentDb sysname = DB_NAME();
IF @CurrentDb <> N'Fitness'
BEGIN
    RAISERROR(N'Connected to database %s, not Fitness. Nothing was changed.', 16, 1, @CurrentDb);
    RETURN;
END;

IF @Step = 1
BEGIN
    ALTER DATABASE CURRENT SET QUERY_STORE = ON;
    ALTER DATABASE CURRENT SET QUERY_STORE
        (OPERATION_MODE = READ_WRITE, MAX_STORAGE_SIZE_MB = 200, QUERY_CAPTURE_MODE = AUTO,
         CLEANUP_POLICY = (STALE_QUERY_THRESHOLD_DAYS = 90));
    PRINT N'Query Store is on. Use the API normally for a few days, then run this script with @Step = 2.';
END
ELSE IF @Step = 2
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.database_query_store_options WHERE actual_state_desc = N'READ_WRITE')
    BEGIN
        RAISERROR(N'Query Store is not on (run @Step = 1 first and wait a few days). Nothing was changed.', 16, 1);
        RETURN;
    END;
    ALTER DATABASE CURRENT SET COMPATIBILITY_LEVEL = 170;
    ALTER DATABASE CURRENT SET QUOTED_IDENTIFIER ON;
    ALTER DATABASE CURRENT SET ANSI_NULLS ON;
    ALTER DATABASE CURRENT SET ANSI_PADDING ON;
    PRINT N'Compatibility level 170; QUOTED_IDENTIFIER, ANSI_NULLS and ANSI_PADDING defaults ON.';

    PRINT N'Modules in dbo still created with QUOTED_IDENTIFIER OFF (recreate by republishing the project):';
    SELECT OBJECT_SCHEMA_NAME(m.object_id) AS SchemaName, OBJECT_NAME(m.object_id) AS ObjectName, o.type_desc
    FROM sys.sql_modules AS m JOIN sys.objects AS o ON o.object_id = m.object_id
    WHERE m.uses_quoted_identifier = 0 AND OBJECT_SCHEMA_NAME(m.object_id) = N'dbo'
    ORDER BY ObjectName;
END
ELSE
    RAISERROR(N'@Step must be 1 or 2.', 16, 1);

SELECT name, compatibility_level, is_quoted_identifier_on, is_ansi_nulls_on, is_ansi_padding_on,
       is_query_store_on, page_verify_option_desc   -- expect CHECKSUM
FROM sys.databases WHERE name = DB_NAME();
GO

-- S2_missedmiles_date_default.sql
-- S2: dbo.MissedMiles.Date defaults to ((1)/(1))/(1990), which is integer arithmetic: it evaluates to 0, i.e. 1900-01-01.
-- Replaces it with today's date (the date part of GETDATE(), stored at midnight like the other entries).
-- No existing row has the bad date (production export 2026-10-31); the check at the end confirms it.
-- Re-runnable: does nothing if the default is already today's date. Run on staging, then production:
--   sqlcmd -S .\DEVELOPMENT -d Fitness -E -I -b -i fixes\S2_missedmiles_date_default.sql
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @CurrentDb sysname = DB_NAME();
IF @CurrentDb <> N'Fitness'
BEGIN
    RAISERROR(N'Connected to database %s, not Fitness. Nothing was changed.', 16, 1, @CurrentDb);
    RETURN;
END;

DECLARE @Definition nvarchar(max) =
    (SELECT dc.[definition] FROM sys.default_constraints AS dc WHERE dc.name = N'DF_MissedMiles_Date' AND dc.parent_object_id = OBJECT_ID(N'dbo.MissedMiles'));
PRINT CONCAT(N'Current default: ', COALESCE(@Definition, N'(none)'));

IF @Definition = N'(CONVERT([date],getdate()))'
    PRINT N'Already today''s date. Nothing to do.';
ELSE
BEGIN
    BEGIN TRANSACTION;
        IF @Definition IS NOT NULL
            ALTER TABLE dbo.MissedMiles DROP CONSTRAINT DF_MissedMiles_Date;
        ALTER TABLE dbo.MissedMiles ADD CONSTRAINT DF_MissedMiles_Date DEFAULT (CONVERT(date, GETDATE())) FOR [Date];
    COMMIT;
    PRINT N'DF_MissedMiles_Date now defaults to today''s date.';
END;

SELECT COUNT(*) AS RowsDated1900 FROM dbo.MissedMiles WHERE [Date] < '19010101';   -- expect 0
GO

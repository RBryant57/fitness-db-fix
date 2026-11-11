-- 01c_restore_GetLastEntries.sql
-- dbo.GetLastEntries is part of the live database and must not be archived (the API uses it).
-- Step 01 no longer moves it. This script is for a database where an earlier version of step 01 already did
-- (staging, 2026-10-22): it moves archive.GetLastEntries back to dbo, so the fixed version applied by 00b is live again.
-- Re-runnable: it does nothing when the procedure is already in dbo. Moving it drops any permissions on it, so
-- 04_permissions.sql grants EXECUTE on it to FitnessApp.
-- sqlcmd -S .\DEVELOPMENT -d Fitness -E -I -b -i 01c_restore_GetLastEntries.sql
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @CurrentDb sysname = DB_NAME();
IF @CurrentDb <> N'Fitness'
BEGIN
    RAISERROR(N'Connected to database %s, not Fitness. Nothing was changed.', 16, 1, @CurrentDb);
    RETURN;
END;

IF OBJECT_ID(N'dbo.GetLastEntries', N'P') IS NOT NULL
BEGIN
    IF OBJECT_ID(N'archive.GetLastEntries', N'P') IS NOT NULL
        RAISERROR(N'dbo.GetLastEntries exists and so does archive.GetLastEntries. Drop the archive copy by hand: DROP PROCEDURE archive.GetLastEntries;', 10, 1);
    PRINT N'dbo.GetLastEntries is already in dbo. Nothing to do.';
    RETURN;
END;

IF OBJECT_ID(N'archive.GetLastEntries', N'P') IS NULL
BEGIN
    RAISERROR(N'GetLastEntries is in neither dbo nor archive. Run archive/scripts/00b_apply_procedure_fixes.sql (or db/scripts/procedures/GetLastEntries.sql) to create it.', 16, 1);
    RETURN;
END;

BEGIN TRANSACTION;
    ALTER SCHEMA dbo TRANSFER archive.GetLastEntries;
    IF OBJECT_ID(N'archive.ArchiveLog', N'U') IS NOT NULL
        INSERT archive.ArchiveLog (Note) VALUES (N'Moved GetLastEntries back from archive to dbo: it is a live procedure and is not archived.');
COMMIT;
PRINT N'Moved archive.GetLastEntries back to dbo.GetLastEntries.';
GO

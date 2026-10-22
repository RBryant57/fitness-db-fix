-- Fixed version of dbo.InsertTreadmillRun (2026-10-14). The pre-fix original is archive/procedures-original/InsertTreadmillRun.sql.
-- Deployed by archive/scripts/00b_apply_procedure_fixes.sql; kept for reference after archiving.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.InsertTreadmillRun
-- Changes:
--   * @Notes now defaults to NULL (was '').
--   * Explicit column list (worked today only because the table hasn't changed).
--   * @Distance decimal(9,4) to match the column; run time computed with DATEDIFF(second);
--     rejects EndTime earlier than StartTime.
--   * @Date `date`; times datetime2(0); @Notes nvarchar(max); transaction + TRY/CATCH.
--   * Now returns the new Id (previously returned nothing).
CREATE OR ALTER PROCEDURE dbo.InsertTreadmillRun
    @Date          date,
    @Distance      decimal(9,4),
    @StartTime     datetime2(0),
    @EndTime       datetime2(0),
    @AverageHR     int,
    @MaxHR         int,
    @ElevationGain int,
    @ShoeId        int,
    @Notes         nvarchar(max) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @EndTime < @StartTime
        THROW 50001, N'EndTime must not be earlier than StartTime.', 1;

    DECLARE @RunSeconds int = DATEDIFF(second, @StartTime, @EndTime);
    DECLARE @NewId int;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.TreadmillRun
            ([Date], Distance, StartTime, EndTime,
             RunTimeHours, RunTimeMinutes, RunTimeSeconds,
             AverageHR, MaxHR, ElevationGain, ShoeId, Notes)
        VALUES
            (@Date, @Distance, @StartTime, @EndTime,
             @RunSeconds / 3600, (@RunSeconds % 3600) / 60, @RunSeconds % 60,
             @AverageHR, @MaxHR, @ElevationGain, @ShoeId, @Notes);

        SET @NewId = CAST(SCOPE_IDENTITY() AS int);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    SELECT @NewId AS Id;
END;
GO

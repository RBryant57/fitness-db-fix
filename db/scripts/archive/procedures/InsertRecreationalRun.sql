-- Fixed version of dbo.InsertRecreationalRun (2026-10-14). The pre-fix original is archive/procedures-original/InsertRecreationalRun.sql.
-- Deployed by archive/scripts/00b_apply_procedure_fixes.sql; kept for reference after archiving.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.InsertRecreationalRun
-- Changes:
--   * @Notes now defaults to NULL (was '').
--   * BUG (broken today): INSERT without a column list supplied 21 values for 22 columns. Explicit column list now.
--   * New optional parameter @GpxJsonId.
--   * @Distance and @MaxSpeed decimal(9,4) to match the columns.
--   * Run and path times computed with DATEDIFF(second); rejects EndTime/PathEndTime earlier than StartTime.
--   * @Date `date`; times datetime2(0); @Notes varchar(max); transaction + TRY/CATCH; returns Id.
CREATE OR ALTER PROCEDURE dbo.InsertRecreationalRun
    @Date          date,
    @Distance      decimal(9,4),
    @StartTime     datetime2(0),
    @EndTime       datetime2(0),
    @PathEndTime   datetime2(0),
    @AverageHR     int,
    @MaxHR         int,
    @ElevationGain int,
    @MaxSpeed      decimal(9,4),
    @Wind          nvarchar(255),
    @Temperature   int,
    @Precipitation bit,
    @ShoeId        int,
    @RouteId       int,
    @Notes         varchar(max) = NULL,
    @GpxJsonId     int          = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @EndTime < @StartTime OR @PathEndTime < @StartTime
        THROW 50001, N'EndTime and PathEndTime must not be earlier than StartTime.', 1;

    DECLARE @RunSeconds  int = DATEDIFF(second, @StartTime, @EndTime);
    DECLARE @PathSeconds int = DATEDIFF(second, @StartTime, @PathEndTime);
    DECLARE @NewId int;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.RecreationalRun
            ([Date], Distance, StartTime, EndTime,
             RunTimeHours, RunTimeMinutes, RunTimeSeconds,
             PathEndTime, PathTimeHours, PathTimeMinutes, PathTimeSeconds,
             AverageHR, MaxHR, ElevationGain, MaxSpeed,
             Wind, Temperature, Precipitation, ShoeId, RouteId, GpxJsonId, Notes)
        VALUES
            (@Date, @Distance, @StartTime, @EndTime,
             @RunSeconds / 3600, (@RunSeconds % 3600) / 60, @RunSeconds % 60,
             @PathEndTime, @PathSeconds / 3600, (@PathSeconds % 3600) / 60, @PathSeconds % 60,
             @AverageHR, @MaxHR, @ElevationGain, @MaxSpeed,
             @Wind, @Temperature, @Precipitation, @ShoeId, @RouteId, @GpxJsonId, @Notes);

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

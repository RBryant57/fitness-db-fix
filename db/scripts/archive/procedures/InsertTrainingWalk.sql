-- Fixed version of dbo.InsertTrainingWalk (2026-10-14). The pre-fix original is archive/procedures-original/InsertTrainingWalk.sql.
-- Deployed by archive/scripts/00b_apply_procedure_fixes.sql; kept for reference after archiving.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.InsertTrainingWalk
-- Changes:
--   * @Notes now defaults to NULL (was '').
--   * BUG (broken today): INSERT without a column list supplied 18 values for 21 columns. Explicit column list now.
--   * New optional parameters @NumberOfAttempts, @NumberOfSuccesses, @GpxJsonId.
--   * @Distance and @MaxSpeed decimal(9,4) to match the columns.
--   * Walk time computed with DATEDIFF(second); rejects EndTime earlier than StartTime.
--   * @Date `date`; times datetime2(0); @Notes varchar(max); transaction + TRY/CATCH; returns Id.
CREATE OR ALTER PROCEDURE dbo.InsertTrainingWalk
    @Date              date,
    @Distance          decimal(9,4),
    @StartTime         datetime2(0),
    @EndTime           datetime2(0),
    @AverageHR         int,
    @MaxHR             int,
    @ElevationGain     int,
    @MaxSpeed          decimal(9,4),
    @WindSpeed         int,
    @WindDirection     nvarchar(3),
    @Temperature       int,
    @Precipitation     bit,
    @ShoeId            int,
    @RouteId           int,
    @Notes             varchar(max) = NULL,
    @NumberOfAttempts  int          = 0,
    @NumberOfSuccesses int          = 0,
    @GpxJsonId         int          = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @EndTime < @StartTime
        THROW 50001, N'EndTime must not be earlier than StartTime.', 1;

    DECLARE @WalkSeconds int = DATEDIFF(second, @StartTime, @EndTime);
    DECLARE @NewId int;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.TrainingWalk
            ([Date], Distance, StartTime, EndTime,
             WalkTimeHours, WalkTimeMinutes, WalkTimeSeconds,
             AverageHR, MaxHR, ElevationGain, MaxSpeed,
             WindSpeed, WindDirection, Temperature, Precipitation,
             ShoeId, RouteId, NumberOfAttempts, NumberOfSuccesses, GpxJsonId, Notes)
        VALUES
            (@Date, @Distance, @StartTime, @EndTime,
             @WalkSeconds / 3600, (@WalkSeconds % 3600) / 60, @WalkSeconds % 60,
             @AverageHR, @MaxHR, @ElevationGain, @MaxSpeed,
             @WindSpeed, RTRIM(@WindDirection), @Temperature, @Precipitation,
             @ShoeId, @RouteId, @NumberOfAttempts, @NumberOfSuccesses, @GpxJsonId, @Notes);

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

-- Fixed version of dbo.InsertRecreationalRide (2026-10-14). The pre-fix original is archive/procedures-original/InsertRecreationalRide.sql.
-- Deployed by archive/scripts/00b_apply_procedure_fixes.sql; kept for reference after archiving.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.InsertRecreationalRide
-- Changes:
--   * @Notes now defaults to NULL (was '').
--   * BUG (broken today): INSERT without a column list supplied 23 values for 25 columns. Explicit column list now.
--   * New optional parameters @Distance and @GpxJsonId.
--   * Ride and bike times computed with DATEDIFF(second); rejects EndTime/BikeEndTime earlier than StartTime.
--   * @MaxSpeed decimal(9,4) to match the column; @Date `date`; times datetime2(0); @Notes varchar(max).
--   * Transaction + TRY/CATCH; returns Id.
CREATE OR ALTER PROCEDURE dbo.InsertRecreationalRide
    @Date           date,
    @StartOdometer  int,
    @EndOdometer    int,
    @StartTime      datetime2(0),
    @EndTime        datetime2(0),
    @BikeEndTime    datetime2(0),
    @AverageHR      int,
    @MaxHR          int,
    @AverageCadence int,
    @ElevationGain  int,
    @MaxSpeed       decimal(9,4),
    @Wind           nvarchar(255),
    @Temperature    int,
    @Precipitation  bit,
    @BikeId         int,
    @RouteId        int,
    @Notes          varchar(max) = NULL,
    @Distance       decimal(9,4) = NULL,
    @GpxJsonId      int          = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @EndTime < @StartTime OR @BikeEndTime < @StartTime
        THROW 50001, N'EndTime and BikeEndTime must not be earlier than StartTime.', 1;

    DECLARE @RideSeconds int = DATEDIFF(second, @StartTime, @EndTime);
    DECLARE @BikeSeconds int = DATEDIFF(second, @StartTime, @BikeEndTime);
    DECLARE @NewId int;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.RecreationalRide
            ([Date], StartOdometer, EndOdometer, Distance, StartTime, EndTime,
             RideTimeHours, RideTimeMinutes, RideTimeSeconds,
             BikeEndTime, BikeTimeHours, BikeTimeMinutes, BikeTimeSeconds,
             AverageHR, MaxHR, AverageCadence, ElevationGain, MaxSpeed,
             Wind, Temperature, Precipitation, BikeId, RouteId, GpxJsonId, Notes)
        VALUES
            (@Date, @StartOdometer, @EndOdometer, @Distance, @StartTime, @EndTime,
             @RideSeconds / 3600, (@RideSeconds % 3600) / 60, @RideSeconds % 60,
             @BikeEndTime, @BikeSeconds / 3600, (@BikeSeconds % 3600) / 60, @BikeSeconds % 60,
             @AverageHR, @MaxHR, @AverageCadence, @ElevationGain, @MaxSpeed,
             @Wind, @Temperature, @Precipitation, @BikeId, @RouteId, @GpxJsonId, @Notes);

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

-- Fixed version of dbo.InsertTrainingRide (2026-10-14). The pre-fix original is archive/procedures-original/InsertTrainingRide.sql.
-- Deployed by archive/scripts/00b_apply_procedure_fixes.sql; kept for reference after archiving.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.InsertTrainingRide
-- Changes:
--   * @Notes now defaults to NULL (was '').
--   * BUG (broken today): INSERT without a column list supplied 20 values for 24 columns, so every call failed.
--     Now uses an explicit column list.
--   * New optional parameters for the columns added since the proc was written:
--     @Distance, @NumberOfAttempts, @NumberOfSuccesses, @GpxJsonId.
--   * Ride time computed from DATEDIFF(second) instead of DATEPART on datetime subtraction (no 24 h wrap, works with datetime2).
--   * Rejects EndTime earlier than StartTime.
--   * @MaxSpeed widened to decimal(9,4) to match the column (was decimal(5,2)); @Date is `date`; times are datetime2(0);
--     @Notes is varchar(max) (column is text; parameter type no longer deprecated).
--   * Transaction + TRY/CATCH; returns the new Id as an int column named Id.
CREATE OR ALTER PROCEDURE dbo.InsertTrainingRide
    @Date              date,
    @StartOdometer     int,
    @EndOdometer       int,
    @StartTime         datetime2(0),
    @EndTime           datetime2(0),
    @AverageHR         int,
    @MaxHR             int,
    @AverageCadence    int,
    @ElevationGain     int,
    @MaxSpeed          decimal(9,4),
    @WindSpeed         int,
    @WindDirection     nvarchar(3),
    @Temperature       int,
    @Precipitation     bit,
    @BikeId            int,
    @RouteId           int,
    @Notes             varchar(max)  = NULL,
    @Distance          decimal(9,4)  = NULL,
    @NumberOfAttempts  int           = 0,
    @NumberOfSuccesses int           = 0,
    @GpxJsonId         int           = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @EndTime < @StartTime
        THROW 50001, N'EndTime must not be earlier than StartTime.', 1;

    DECLARE @RideSeconds int = DATEDIFF(second, @StartTime, @EndTime);
    DECLARE @NewId int;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.TrainingRide
            ([Date], StartOdometer, EndOdometer, Distance, StartTime, EndTime,
             RideTimeHours, RideTimeMinutes, RideTimeSeconds,
             AverageHR, MaxHR, AverageCadence, ElevationGain, MaxSpeed,
             WindSpeed, WindDirection, Temperature, Precipitation,
             BikeId, RouteId, NumberOfAttempts, NumberOfSuccesses, GpxJsonId, Notes)
        VALUES
            (@Date, @StartOdometer, @EndOdometer, @Distance, @StartTime, @EndTime,
             @RideSeconds / 3600, (@RideSeconds % 3600) / 60, @RideSeconds % 60,
             @AverageHR, @MaxHR, @AverageCadence, @ElevationGain, @MaxSpeed,
             @WindSpeed, RTRIM(@WindDirection), @Temperature, @Precipitation,
             @BikeId, @RouteId, @NumberOfAttempts, @NumberOfSuccesses, @GpxJsonId, @Notes);

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

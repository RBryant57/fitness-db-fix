-- Fixed version of dbo.InsertStationaryRide (2026-10-14). The pre-fix original is archive/procedures-original/InsertStationaryRide.sql.
-- Deployed by archive/scripts/00b_apply_procedure_fixes.sql; kept for reference after archiving.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.InsertStationaryRide
-- Changes:
--   * @Notes now defaults to NULL (was '').
--   * BUG (broken today): INSERT without a column list supplied 13 values for 14 columns. Explicit column list now.
--   * New optional parameter @Distance.
--   * Ride time computed with DATEDIFF(second); rejects EndTime earlier than StartTime.
--   * SELECT @@IDENTITY replaced by SCOPE_IDENTITY(); @Date `date`; times datetime2(0); @Notes nvarchar(max).
--   * Transaction + TRY/CATCH; returns Id.
CREATE OR ALTER PROCEDURE dbo.InsertStationaryRide
    @Date           date,
    @StartOdometer  int,
    @EndOdometer    int,
    @StartTime      datetime2(0),
    @EndTime        datetime2(0),
    @AverageHR      int,
    @MaxHR          int,
    @AverageCadence int,
    @BikeId         int           = NULL,
    @Notes          nvarchar(max) = NULL,
    @Distance       decimal(9,4)  = NULL
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

        INSERT INTO dbo.StationaryRide
            ([Date], StartOdometer, EndOdometer, Distance, StartTime, EndTime,
             RideTimeHours, RideTimeMinutes, RideTimeSeconds,
             AverageHR, MaxHR, AverageCadence, BikeId, Notes)
        VALUES
            (@Date, @StartOdometer, @EndOdometer, @Distance, @StartTime, @EndTime,
             @RideSeconds / 3600, (@RideSeconds % 3600) / 60, @RideSeconds % 60,
             @AverageHR, @MaxHR, @AverageCadence, @BikeId, @Notes);

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

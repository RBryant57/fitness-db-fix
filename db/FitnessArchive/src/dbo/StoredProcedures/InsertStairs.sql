
-- dbo.InsertStairs
-- Changes:
--   * @Notes now defaults to NULL (was '').
--   * Explicit column list; stair time computed with DATEDIFF(second); rejects EndTime earlier than StartTime.
--   * @Date `date`; times datetime2(0); @Notes nvarchar(max); transaction + TRY/CATCH.
--   * Now returns the new Id (previously returned nothing).
CREATE   PROCEDURE dbo.InsertStairs
    @Date          date,
    @StairQuantity int,
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

    DECLARE @StairSeconds int = DATEDIFF(second, @StartTime, @EndTime);
    DECLARE @NewId int;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.Stairs
            ([Date], StairQuantity, StartTime, EndTime,
             StairTimeHours, StairTimeMinutes, StairTimeSeconds,
             AverageHR, MaxHR, ElevationGain, ShoeId, Notes)
        VALUES
            (@Date, @StairQuantity, @StartTime, @EndTime,
             @StairSeconds / 3600, (@StairSeconds % 3600) / 60, @StairSeconds % 60,
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


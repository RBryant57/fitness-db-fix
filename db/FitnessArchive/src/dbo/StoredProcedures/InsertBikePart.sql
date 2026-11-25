
-- dbo.InsertBikePart
-- Changes:
--   * SELECT @@IDENTITY replaced by SCOPE_IDENTITY(), returned as an int column named Id.
--   * @StartDate is `date`; transaction + TRY/CATCH.
CREATE   PROCEDURE dbo.InsertBikePart
    @BikeId          int,
    @PartId          int,
    @StartDate       date,
    @OdometerReading int
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NewId int;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.BikePart
            (BikeId, PartId, StartDate, OdometerReading)
        VALUES
            (@BikeId, @PartId, @StartDate, @OdometerReading);

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


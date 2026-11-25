
-- dbo.InsertNonRideMiles
-- Changes:
--   * @Notes now defaults to NULL (was '').
--   * Explicit column list; transaction + TRY/CATCH.
--   * Rejects EndOdometer < StartOdometer.
--   * @Date is `date` (matches the column); now returns the new Id.
CREATE   PROCEDURE dbo.InsertNonRideMiles
    @Date          date,
    @StartOdometer int,
    @EndOdometer   int,
    @BikeId        int,
    @Notes         nvarchar(max) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @EndOdometer < @StartOdometer
        THROW 50002, N'EndOdometer must not be less than StartOdometer.', 1;

    DECLARE @NewId int;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.NonRideMiles
            ([Date], StartOdometer, EndOdometer, BikeId, Notes)
        VALUES
            (@Date, @StartOdometer, @EndOdometer, @BikeId, @Notes);

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


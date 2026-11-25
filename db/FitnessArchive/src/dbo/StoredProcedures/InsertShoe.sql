
-- dbo.InsertShoe
-- Changes:
--   * @Notes now defaults to NULL (was '').
--   * SELECT @@IDENTITY replaced by SCOPE_IDENTITY(), returned as an int column named Id.
--   * Explicit column list; dates are `date`; @Notes nvarchar(max); transaction + TRY/CATCH.
CREATE   PROCEDURE dbo.InsertShoe
    @Name            nvarchar(50),
    @ManufacturerId  int,
    @ShoeTypeId      int,
    @AcquisitionDate date,
    @RetireDate      date = NULL,
    @Notes           nvarchar(max) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NewId int;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.Shoe
            ([Name], ManufacturerId, ShoeTypeId, AcquisitionDate, RetireDate, Notes)
        VALUES
            (@Name, @ManufacturerId, @ShoeTypeId, @AcquisitionDate, @RetireDate, @Notes);

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


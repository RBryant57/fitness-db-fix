
-- dbo.InsertManufacturer
-- Changes:
--   * @Notes now defaults to NULL (was '').
--   * SELECT @@IDENTITY replaced by SCOPE_IDENTITY(), returned as an int column named Id.
--   * Explicit column list; @Notes varchar(max); transaction + TRY/CATCH.
CREATE   PROCEDURE dbo.InsertManufacturer
    @Name  nvarchar(50),
    @Notes varchar(max) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NewId int;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.Manufacturer
            ([Name], Notes)
        VALUES
            (@Name, @Notes);

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



-- dbo.UpdatePart
-- Changes:
--   * @Notes now defaults to NULL (was '').
--   * @Notes was nvarchar(255) writing into a text column (silent truncation at 255). Now varchar(max).
--   * Raises an error if the part does not exist; transaction + TRY/CATCH.
CREATE   PROCEDURE dbo.UpdatePart
    @Id             int,
    @ManufacturerId int,
    @PartTypeId     int,
    @Name           nvarchar(50),
    @Notes          varchar(max) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE dbo.Part
        SET ManufacturerId = @ManufacturerId,
            PartTypeId     = @PartTypeId,
            [Name]         = @Name,
            Notes          = @Notes
        WHERE Id = @Id;

        IF @@ROWCOUNT = 0
            THROW 50010, N'Part not found.', 1;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;

GO


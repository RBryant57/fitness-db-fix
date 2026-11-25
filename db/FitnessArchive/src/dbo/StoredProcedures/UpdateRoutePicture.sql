
-- dbo.UpdateRoutePicture
-- Changes:
--   * @ImageDescription varchar(max) instead of text.
--   * Raises an error if the picture does not exist; transaction + TRY/CATCH.
CREATE   PROCEDURE dbo.UpdateRoutePicture
    @Id               int,
    @ImageFileName    nvarchar(100),
    @ImageDescription varchar(max) = ''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE dbo.RoutePicture
        SET ImageFileName    = @ImageFileName,
            ImageDescription = @ImageDescription
        WHERE Id = @Id;

        IF @@ROWCOUNT = 0
            THROW 50010, N'Route picture not found.', 1;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;

GO


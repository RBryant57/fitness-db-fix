
-- dbo.ClearRoutePictures
-- Changes:
--   * Schema-qualified; transaction + TRY/CATCH. Returns the number of rows removed as DeletedCount.
CREATE   PROCEDURE dbo.ClearRoutePictures
    @RouteId int
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Deleted int;

    BEGIN TRY
        BEGIN TRANSACTION;

        DELETE FROM dbo.RoutePicture
        WHERE RouteId = @RouteId;

        SET @Deleted = @@ROWCOUNT;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    SELECT @Deleted AS DeletedCount;
END;

GO


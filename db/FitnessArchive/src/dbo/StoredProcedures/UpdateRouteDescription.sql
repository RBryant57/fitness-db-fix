
-- dbo.UpdateRouteDescription
-- Changes:
--   * @Description varchar(max) instead of text.
--   * Raises an error if the route has no description row (previously a silent no-op); transaction + TRY/CATCH.
CREATE   PROCEDURE dbo.UpdateRouteDescription
    @RouteId     int,
    @Description varchar(max)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE dbo.RouteDisplay
        SET [Description] = @Description
        WHERE RouteId = @RouteId;

        IF @@ROWCOUNT = 0
            THROW 50010, N'Route description not found.', 1;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;

GO


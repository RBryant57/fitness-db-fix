-- Fixed version of dbo.UpdateRouteDescription (2026-10-14). The pre-fix original is archive/procedures-original/UpdateRouteDescription.sql.
-- Deployed by archive/scripts/00b_apply_procedure_fixes.sql; kept for reference after archiving.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.UpdateRouteDescription
-- Changes:
--   * @Description varchar(max) instead of text.
--   * Raises an error if the route has no description row (previously a silent no-op); transaction + TRY/CATCH.
CREATE OR ALTER PROCEDURE dbo.UpdateRouteDescription
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

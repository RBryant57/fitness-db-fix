-- Fixed version of dbo.ClearRouteDirections (2026-10-14). The pre-fix original is archive/procedures-original/ClearRouteDirections.sql.
-- Deployed by archive/scripts/00b_apply_procedure_fixes.sql; kept for reference after archiving.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.ClearRouteDirections
-- Changes:
--   * Schema-qualified; transaction + TRY/CATCH. Returns the number of rows removed as DeletedCount.
CREATE OR ALTER PROCEDURE dbo.ClearRouteDirections
    @Id int
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Deleted int;

    BEGIN TRY
        BEGIN TRANSACTION;

        DELETE FROM dbo.RouteDirection
        WHERE RouteId = @Id;

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

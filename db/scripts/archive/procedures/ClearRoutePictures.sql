-- Fixed version of dbo.ClearRoutePictures (2026-10-14). The pre-fix original is archive/procedures-original/ClearRoutePictures.sql.
-- Deployed by archive/scripts/00b_apply_procedure_fixes.sql; kept for reference after archiving.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.ClearRoutePictures
-- Changes:
--   * Schema-qualified; transaction + TRY/CATCH. Returns the number of rows removed as DeletedCount.
CREATE OR ALTER PROCEDURE dbo.ClearRoutePictures
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

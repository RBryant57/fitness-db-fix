-- Fixed version of dbo.UpdateRoutePicture (2026-10-14). The pre-fix original is archive/procedures-original/UpdateRoutePicture.sql.
-- Deployed by archive/scripts/00b_apply_procedure_fixes.sql; kept for reference after archiving.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.UpdateRoutePicture
-- Changes:
--   * @ImageDescription varchar(max) instead of text.
--   * Raises an error if the picture does not exist; transaction + TRY/CATCH.
CREATE OR ALTER PROCEDURE dbo.UpdateRoutePicture
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

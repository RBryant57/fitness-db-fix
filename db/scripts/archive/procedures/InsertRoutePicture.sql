-- Fixed version of dbo.InsertRoutePicture (2026-10-14). The pre-fix original is archive/procedures-original/InsertRoutePicture.sql.
-- Deployed by archive/scripts/00b_apply_procedure_fixes.sql; kept for reference after archiving.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.InsertRoutePicture
-- Changes:
--   * SELECT @@IDENTITY replaced by SCOPE_IDENTITY(), returned as an int column named Id.
--   * Explicit column list; @ImageDescription varchar(max) (column is NOT NULL text, so the empty-string default is kept).
--   * Transaction + TRY/CATCH.
CREATE OR ALTER PROCEDURE dbo.InsertRoutePicture
    @RouteId          int,
    @ImageFileName    nvarchar(100),
    @ImageDescription varchar(max) = ''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NewId int;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.RoutePicture
            (RouteId, ImageFileName, ImageDescription)
        VALUES
            (@RouteId, @ImageFileName, @ImageDescription);

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

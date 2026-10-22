-- Fixed version of dbo.InsertRouteDescription (2026-10-14). The pre-fix original is archive/procedures-original/InsertRouteDescription.sql.
-- Deployed by archive/scripts/00b_apply_procedure_fixes.sql; kept for reference after archiving.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.InsertRouteDescription
-- Changes:
--   * SELECT @@IDENTITY replaced by SCOPE_IDENTITY(), returned as an int column named Id.
--   * Explicit column list; @Description varchar(max) instead of text; transaction + TRY/CATCH.
CREATE OR ALTER PROCEDURE dbo.InsertRouteDescription
    @RouteId     int,
    @Description varchar(max)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NewId int;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.RouteDisplay
            (RouteId, [Description])
        VALUES
            (@RouteId, @Description);

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

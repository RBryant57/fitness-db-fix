-- Fixed version of dbo.InsertRouteDirection (2026-10-14). The pre-fix original is archive/procedures-original/InsertRouteDirection.sql.
-- Deployed by archive/scripts/00b_apply_procedure_fixes.sql; kept for reference after archiving.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.InsertRouteDirection
-- Changes:
--   * SELECT @@IDENTITY replaced by SCOPE_IDENTITY(), returned as an int column named Id.
--   * @DirectionDescription nvarchar(max) to match the column (was text -> implicit conversion);
--     @DirectionMileMarker decimal(18,1) to match the column.
--   * Explicit column list; transaction + TRY/CATCH.
CREATE OR ALTER PROCEDURE dbo.InsertRouteDirection
    @RouteId              int,
    @DirectionNumber      int,
    @DirectionMileMarker  decimal(18,1),
    @DirectionDescription nvarchar(max)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NewId int;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.RouteDirection
            (RouteId, DirectionNumber, DirectionMileMarker, DirectionDescription)
        VALUES
            (@RouteId, @DirectionNumber, @DirectionMileMarker, @DirectionDescription);

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

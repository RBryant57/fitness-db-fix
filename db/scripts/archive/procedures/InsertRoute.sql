-- Fixed version of dbo.InsertRoute (2026-10-14). The pre-fix original is archive/procedures-original/InsertRoute.sql.
-- Deployed by archive/scripts/00b_apply_procedure_fixes.sql; kept for reference after archiving.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.InsertRoute
-- Changes:
--   * SELECT @@IDENTITY replaced by SCOPE_IDENTITY(), returned as an int column named Id.
--   * An unknown @TypeId (RouteType.EnumId) now raises an error instead of inserting a NULL TypeId.
--   * Explicit column list; @Notes varchar(max); transaction + TRY/CATCH.
--   * Kept: @TypeId is the RouteType *EnumId* and is mapped to RouteType.Id. UpdateRoute now does the same.
CREATE OR ALTER PROCEDURE dbo.InsertRoute
    @Name   nvarchar(50),
    @City   nvarchar(50),
    @State  char(2),
    @TypeId int,
    @Rating int,
    @Notes  varchar(max) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @RouteTypeId int = (SELECT rt.Id FROM dbo.RouteType AS rt WHERE rt.EnumId = @TypeId);

    IF @RouteTypeId IS NULL
        THROW 50004, N'Unknown route type.', 1;

    DECLARE @NewId int;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.[Route]
            ([Name], City, [State], TypeId, Rating, Notes)
        VALUES
            (@Name, @City, @State, @RouteTypeId, @Rating, @Notes);

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

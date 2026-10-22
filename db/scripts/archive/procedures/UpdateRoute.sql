-- Fixed version of dbo.UpdateRoute (2026-10-14). The pre-fix original is archive/procedures-original/UpdateRoute.sql.
-- Deployed by archive/scripts/00b_apply_procedure_fixes.sql; kept for reference after archiving.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.UpdateRoute
-- Changes:
--   * BUG: InsertRoute maps its type argument through RouteType.EnumId, but UpdateRoute wrote @RouteType straight into
--     Route.TypeId. Both now map through EnumId. (Harmless with today's data, where Id = EnumId for both route types,
--     but the two procs disagreed about what the parameter meant.)
--   * Raises an error if the route or route type does not exist.
--   * @Notes varchar(max); transaction + TRY/CATCH.
CREATE OR ALTER PROCEDURE dbo.UpdateRoute
    @Id        int,
    @Name      nvarchar(50),
    @City      nvarchar(50),
    @State     char(2),
    @RouteType int,
    @Rating    int,
    @Notes     varchar(max) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @RouteTypeId int = (SELECT rt.Id FROM dbo.RouteType AS rt WHERE rt.EnumId = @RouteType);

    IF @RouteTypeId IS NULL
        THROW 50004, N'Unknown route type.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE dbo.[Route]
        SET [Name]  = @Name,
            City    = @City,
            [State] = @State,
            TypeId  = @RouteTypeId,
            Rating  = @Rating,
            Notes   = @Notes
        WHERE Id = @Id;

        IF @@ROWCOUNT = 0
            THROW 50010, N'Route not found.', 1;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

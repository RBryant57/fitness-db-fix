-- Fixed version of dbo.UpdateBaseMiles (2026-10-14). The pre-fix original is archive/procedures-original/UpdateBaseMiles.sql.
-- Deployed by archive/scripts/00b_apply_procedure_fixes.sql; kept for reference after archiving.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.UpdateBaseMiles
-- Changes:
--   * BUG: read BaseMiles into a variable, then wrote variable + @Miles back -- not atomic, so two concurrent calls
--     could lose an update. Now a single `SET BaseMiles = BaseMiles + @Miles`.
--   * Raises an error if the bike does not exist; transaction + TRY/CATCH.
CREATE OR ALTER PROCEDURE dbo.UpdateBaseMiles
    @BikeId int,
    @Miles  int
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE dbo.Bike
        SET BaseMiles = BaseMiles + @Miles
        WHERE Id = @BikeId;

        IF @@ROWCOUNT = 0
            THROW 50010, N'Bike not found.', 1;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

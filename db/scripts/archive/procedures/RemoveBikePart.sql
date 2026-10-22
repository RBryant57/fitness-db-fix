-- Fixed version of dbo.RemoveBikePart (2026-10-14). The pre-fix original is archive/procedures-original/RemoveBikePart.sql.
-- Deployed by archive/scripts/00b_apply_procedure_fixes.sql; kept for reference after archiving.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.RemoveBikePart
-- Changes:
--   * @EndDate is `date`; raises an error if the BikePart row does not exist; transaction + TRY/CATCH.
CREATE OR ALTER PROCEDURE dbo.RemoveBikePart
    @Id      int,
    @EndDate date
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE dbo.BikePart
        SET EndDate = @EndDate
        WHERE Id = @Id;

        IF @@ROWCOUNT = 0
            THROW 50010, N'BikePart not found.', 1;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

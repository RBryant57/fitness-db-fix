-- Fixed version of dbo.InsertLiftingSession (2026-10-14). The pre-fix original is archive/procedures-original/InsertLiftingSession.sql.
-- Deployed by archive/scripts/00b_apply_procedure_fixes.sql; kept for reference after archiving.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.InsertLiftingSession
-- Changes:
--   * @Notes now defaults to NULL (was '').
--   * SELECT @@IDENTITY replaced by SCOPE_IDENTITY(), returned as an int column named Id.
--   * @Date `date`; @Notes nvarchar(max); transaction + TRY/CATCH.
CREATE OR ALTER PROCEDURE dbo.InsertLiftingSession
    @Date         date,
    @CircuitId    int,
    @NumberOfSets int,
    @Notes        nvarchar(max) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NewId int;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.LiftingSession
            ([Date], CircuitId, NumberOfSets, Notes)
        VALUES
            (@Date, @CircuitId, @NumberOfSets, @Notes);

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

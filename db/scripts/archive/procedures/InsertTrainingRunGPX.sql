-- Fixed version of dbo.InsertTrainingRunGPX (2026-10-14). The pre-fix original is archive/procedures-original/InsertTrainingRunGPX.sql.
-- Deployed by archive/scripts/00b_apply_procedure_fixes.sql; kept for reference after archiving.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.InsertTrainingRunGPX
-- Changes:
--   * @Notes now defaults to NULL (was '').
--   * BUG: a `GRANT EXECUTE ... TO [FitnessLogger]` had been pasted into the procedure body (no GO), so it re-ran
--     on every call and failed for callers without GRANT rights. Removed.
--   * Explicit column list; @Notes nvarchar(max) (column is ntext; was declared text).
--   * Transaction + TRY/CATCH; now returns the new Id (previously returned nothing).
CREATE OR ALTER PROCEDURE dbo.InsertTrainingRunGPX
    @TrainingRunId int,
    @GPX           nvarchar(max),
    @Notes         nvarchar(max) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NewId int;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.TrainingRunGPX
            (TrainingRunId, GPX, Notes)
        VALUES
            (@TrainingRunId, @GPX, @Notes);

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

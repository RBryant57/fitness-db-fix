-- Fixed version of dbo.InsertMissedMiles (2026-10-14). The pre-fix original is archive/procedures-original/InsertMissedMiles.sql.
-- Deployed by archive/scripts/00b_apply_procedure_fixes.sql; kept for reference after archiving.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.InsertMissedMiles
-- Changes:
--   * @Notes now defaults to NULL (was '').
--   * BUG: @Miles was `int`, so fractional missed miles were truncated before reaching the decimal(18,2) column.
--   * Explicit column list; @Date `date`; transaction + TRY/CATCH; now returns the new Id.
CREATE OR ALTER PROCEDURE dbo.InsertMissedMiles
    @Date  date,
    @Miles decimal(18,2),
    @Type  int,
    @Notes nvarchar(max) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NewId int;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.MissedMiles
            ([Date], Miles, ExerciseTypeId, Notes)
        VALUES
            (@Date, @Miles, @Type, @Notes);

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

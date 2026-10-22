-- Fixed version of dbo.InsertMissedMilesByType (2026-10-14). The pre-fix original is archive/procedures-original/InsertMissedMilesByType.sql.
-- Deployed by archive/scripts/00b_apply_procedure_fixes.sql; kept for reference after archiving.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.InsertMissedMilesByType
-- Changes:
--   * BUG (broken today): INSERT without a column list supplied 3 values for 4 columns (Notes missing). Explicit column list now.
--   * New optional @Notes parameter.
--   * @TypeName nvarchar(50) to match ExerciseType.Name (was varchar); an unknown type name now raises an error
--     instead of attempting to insert a NULL ExerciseTypeId.
--   * @Date `date`; transaction + TRY/CATCH; returns the new Id.
CREATE OR ALTER PROCEDURE dbo.InsertMissedMilesByType
    @Date     date,
    @Miles    decimal(18,2),
    @TypeName nvarchar(50),
    @Notes    nvarchar(max) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @ExerciseTypeId int = (SELECT et.Id FROM dbo.ExerciseType AS et WHERE et.[Name] = @TypeName);

    IF @ExerciseTypeId IS NULL
        THROW 50003, N'Unknown exercise type name.', 1;

    DECLARE @NewId int;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.MissedMiles
            ([Date], Miles, ExerciseTypeId, Notes)
        VALUES
            (@Date, @Miles, @ExerciseTypeId, @Notes);

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

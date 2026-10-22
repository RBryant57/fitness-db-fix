-- Fixed version of dbo.GetMissedMilesByDateByType (2026-10-14). The pre-fix original is archive/procedures-original/GetMissedMilesByDateByType.sql.
-- Deployed by archive/scripts/00b_apply_procedure_fixes.sql; kept for reference after archiving.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.GetMissedMilesByDateByType
-- Changes:
--   * @StartDate and @EndDate are independently optional (end inclusive); two branches merged.
--   * An unknown @TypeName raises an error instead of silently returning 0.
--   * Result column named Miles; schema-qualified.
CREATE OR ALTER PROCEDURE dbo.GetMissedMilesByDateByType
    @StartDate date = NULL,
    @EndDate   date = NULL,
    @TypeName  nvarchar(50)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ExerciseTypeId int = (SELECT et.Id FROM dbo.ExerciseType AS et WHERE et.[Name] = @TypeName);

    IF @ExerciseTypeId IS NULL
        THROW 50003, N'Unknown exercise type name.', 1;

    DECLARE @EndExclusive date = DATEADD(day, 1, @EndDate);

    SELECT COALESCE(SUM(mm.Miles), 0) AS Miles
    FROM dbo.MissedMiles AS mm
    WHERE mm.ExerciseTypeId = @ExerciseTypeId
      AND (@StartDate IS NULL OR mm.[Date] >= @StartDate)
      AND (@EndDate   IS NULL OR mm.[Date] <  @EndExclusive);
END;
GO

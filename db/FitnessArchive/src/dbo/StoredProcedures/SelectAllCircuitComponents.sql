
-- dbo.SelectAllCircuitComponents
-- Changes:
--   * Unnamed Notes column now aliased; ntext cast to nvarchar(max); ORDER BY ExerciseName; schema-qualified.
CREATE   PROCEDURE dbo.SelectAllCircuitComponents
AS
BEGIN
    SET NOCOUNT ON;

    SELECT cc.Id,
           cc.ExerciseName,
           COALESCE(CAST(cc.Notes AS nvarchar(max)), N'') AS Notes
    FROM dbo.CircuitComponent AS cc
    ORDER BY cc.ExerciseName;
END;

GO



-- dbo.GetCircuitComponentById
-- Changes:
--   * ntext Notes cast to nvarchar(max) and NULL returned as ''; schema-qualified.
CREATE   PROCEDURE dbo.GetCircuitComponentById
    @CircuitComponentId int
AS
BEGIN
    SET NOCOUNT ON;

    SELECT cc.Id,
           cc.ExerciseName,
           COALESCE(CAST(cc.Notes AS nvarchar(max)), N'') AS Notes
    FROM dbo.CircuitComponent AS cc
    WHERE cc.Id = @CircuitComponentId;
END;

GO


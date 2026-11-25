
-- dbo.GetCircuitById
-- Changes:
--   * ntext Notes cast to nvarchar(max) and NULL returned as ''; schema-qualified.
CREATE   PROCEDURE dbo.GetCircuitById
    @CircuitId int
AS
BEGIN
    SET NOCOUNT ON;

    SELECT c.Id,
           c.[Name],
           COALESCE(CAST(c.Notes AS nvarchar(max)), N'') AS Notes
    FROM dbo.Circuit AS c
    WHERE c.Id = @CircuitId;
END;

GO


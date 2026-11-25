
-- dbo.SelectAllCircuits
-- Changes:
--   * Unnamed Notes column now aliased; ntext cast to nvarchar(max); ORDER BY Name; schema-qualified.
CREATE   PROCEDURE dbo.SelectAllCircuits
AS
BEGIN
    SET NOCOUNT ON;

    SELECT c.Id,
           c.[Name],
           COALESCE(CAST(c.Notes AS nvarchar(max)), N'') AS Notes
    FROM dbo.Circuit AS c
    ORDER BY c.[Name];
END;

GO


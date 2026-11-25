
-- dbo.SelectAllPartTypes
-- Changes:
--   * ORDER BY Name; schema-qualified.
CREATE   PROCEDURE dbo.SelectAllPartTypes
AS
BEGIN
    SET NOCOUNT ON;

    SELECT pt.Id,
           pt.[Name]
    FROM dbo.PartType AS pt
    ORDER BY pt.[Name];
END;

GO


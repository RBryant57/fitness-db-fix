
-- dbo.GetPartTypeByName
-- Changes:
--   * Schema-qualified.
CREATE   PROCEDURE dbo.GetPartTypeByName
    @PartTypeName nvarchar(50)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT pt.Id,
           pt.[Name]
    FROM dbo.PartType AS pt
    WHERE pt.[Name] = @PartTypeName;
END;

GO


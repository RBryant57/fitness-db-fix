
-- dbo.GetPartTypeById
-- Changes:
--   * Schema-qualified.
CREATE   PROCEDURE dbo.GetPartTypeById
    @PartTypeId int
AS
BEGIN
    SET NOCOUNT ON;

    SELECT pt.Id,
           pt.[Name]
    FROM dbo.PartType AS pt
    WHERE pt.Id = @PartTypeId;
END;

GO


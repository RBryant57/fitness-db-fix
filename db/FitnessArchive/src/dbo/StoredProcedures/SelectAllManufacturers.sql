
-- dbo.SelectAllManufacturers
-- Changes:
--   * ORDER BY Name; schema-qualified.
CREATE   PROCEDURE dbo.SelectAllManufacturers
AS
BEGIN
    SET NOCOUNT ON;

    SELECT m.Id,
           m.[Name]
    FROM dbo.Manufacturer AS m
    ORDER BY m.[Name];
END;

GO


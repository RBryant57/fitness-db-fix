
-- dbo.GetManufacturerById
-- Changes:
--   * Notes added (cast from text); schema-qualified.
CREATE   PROCEDURE dbo.GetManufacturerById
    @ManufacturerId int
AS
BEGIN
    SET NOCOUNT ON;

    SELECT m.Id,
           m.[Name],
           COALESCE(CAST(m.Notes AS varchar(max)), '') AS Notes
    FROM dbo.Manufacturer AS m
    WHERE m.Id = @ManufacturerId;
END;

GO



-- dbo.SelectAllBikes
-- Changes:
--   * Unnamed Notes column now aliased; text cast to varchar(max); AcquisitionDate added; schema-qualified.
--   * Deterministic ORDER BY BikeName.
CREATE   PROCEDURE dbo.SelectAllBikes
AS
BEGIN
    SET NOCOUNT ON;

    SELECT b.Id,
           b.[Name]                                        AS BikeName,
           bt.[Name]                                       AS TypeName,
           b.TypeId,
           b.BaseMiles,
           b.AcquisitionDate,
           COALESCE(CAST(b.Notes AS varchar(max)), '')     AS Notes,
           m.Id                                            AS ManufacturerId,
           m.[Name]                                        AS ManufacturerName,
           COALESCE(CAST(m.Notes AS varchar(max)), '')     AS ManufacturerNotes
    FROM dbo.Bike AS b
    INNER JOIN dbo.BikeType     AS bt ON bt.Id = b.TypeId
    INNER JOIN dbo.Manufacturer AS m  ON m.Id  = b.ManufacturerId
    ORDER BY b.[Name];
END;

GO


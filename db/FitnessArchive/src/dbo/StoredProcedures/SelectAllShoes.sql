
-- dbo.SelectAllShoes
-- Changes:
--   * Typo'd alias ShoeAquisitionDate corrected to ShoeAcquisitionDate.
--   * ntext Notes cast to nvarchar(max); ORDER BY ShoeName; schema-qualified.
CREATE   PROCEDURE dbo.SelectAllShoes
AS
BEGIN
    SET NOCOUNT ON;

    SELECT s.Id                                            AS ShoeId,
           s.[Name]                                        AS ShoeName,
           s.AcquisitionDate                               AS ShoeAcquisitionDate,
           s.RetireDate                                    AS ShoeRetireDate,
           COALESCE(CAST(s.Notes AS nvarchar(max)), N'')   AS ShoeNotes,
           m.Id                                            AS ManufacturerId,
           m.[Name]                                        AS ManufacturerName,
           COALESCE(CAST(m.Notes AS varchar(max)), '')     AS ManufacturerNotes,
           st.Id                                           AS ShoeTypeId,
           st.[Name]                                       AS ShoeTypeName
    FROM dbo.Shoe AS s
    INNER JOIN dbo.Manufacturer AS m  ON m.Id  = s.ManufacturerId
    INNER JOIN dbo.ShoeType     AS st ON st.Id = s.ShoeTypeId
    ORDER BY s.[Name];
END;

GO


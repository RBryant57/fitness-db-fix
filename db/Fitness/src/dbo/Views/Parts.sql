CREATE VIEW dbo.Parts
AS
SELECT     dbo.Part.Id, dbo.Manufacturer.Name AS Manufacturer, dbo.Part.Name AS [Part Name], dbo.PartType.Name AS [Part Type]
FROM         dbo.Manufacturer INNER JOIN
                      dbo.Part ON dbo.Manufacturer.Id = dbo.Part.ManufacturerId INNER JOIN
                      dbo.PartType ON dbo.Part.PartTypeId = dbo.PartType.Id

GO


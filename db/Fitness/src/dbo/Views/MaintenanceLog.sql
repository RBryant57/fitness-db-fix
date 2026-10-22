CREATE VIEW dbo.MaintenanceLog
AS
SELECT     dbo.Maintenance.Date AS [Operation Date], dbo.Bike.Name AS Bike, dbo.Manufacturer.Name AS Manufacturer, dbo.Part.Name AS Part, 
                      dbo.PartType.Name AS [Part Type], dbo.Maintenance.ActionTaken AS [Action Taken], dbo.Maintenance.Odometer, dbo.Maintenance.Notes
FROM         dbo.Maintenance INNER JOIN
                      dbo.Part ON dbo.Maintenance.PartId = dbo.Part.Id INNER JOIN
                      dbo.Manufacturer ON dbo.Part.ManufacturerId = dbo.Manufacturer.Id INNER JOIN
                      dbo.PartType ON dbo.Part.PartTypeId = dbo.PartType.Id INNER JOIN
                      dbo.Bike ON dbo.Maintenance.BikeId = dbo.Bike.Id

GO



GO


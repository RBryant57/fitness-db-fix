-- V3_maintenancelog_bikeid.sql
-- V3: dbo.MaintenanceLog shows the bike's NAME in a column called Bike. This adds the bike's key, BikeId, as a new last
-- column so callers can filter by id. Every existing column keeps its name, type and position, so nothing that
-- selects named columns changes. (Check the API doesn't read this view by column position.)
-- The SQL project's MaintenanceLog.sql has the same definition.
-- sqlcmd -S <server> -d Fitness -E -I -b -i V3_maintenancelog_bikeid.sql

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @CurrentDb sysname = DB_NAME();
IF @CurrentDb <> N'Fitness'
BEGIN
    RAISERROR(N'Connected to database %s, not Fitness. Nothing was changed.', 16, 1, @CurrentDb);
    SET NOEXEC ON;
END;
GO

SET QUOTED_IDENTIFIER ON;
GO
SET ANSI_NULLS ON;
GO
CREATE OR ALTER VIEW dbo.MaintenanceLog
AS
SELECT     dbo.Maintenance.Date AS [Operation Date], dbo.Bike.Name AS Bike, dbo.Manufacturer.Name AS Manufacturer, dbo.Part.Name AS Part, 
                      dbo.PartType.Name AS [Part Type], dbo.Maintenance.ActionTaken AS [Action Taken], dbo.Maintenance.Odometer, dbo.Maintenance.Notes, dbo.Maintenance.BikeId
FROM         dbo.Maintenance INNER JOIN
                      dbo.Part ON dbo.Maintenance.PartId = dbo.Part.Id INNER JOIN
                      dbo.Manufacturer ON dbo.Part.ManufacturerId = dbo.Manufacturer.Id INNER JOIN
                      dbo.PartType ON dbo.Part.PartTypeId = dbo.PartType.Id INNER JOIN
                      dbo.Bike ON dbo.Maintenance.BikeId = dbo.Bike.Id
GO
PRINT N'dbo.MaintenanceLog now ends with BikeId.';
GO

SET NOEXEC OFF;
GO

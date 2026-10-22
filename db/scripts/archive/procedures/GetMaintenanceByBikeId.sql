-- Fixed version of dbo.GetMaintenanceByBikeId (2026-10-14). The pre-fix original is archive/procedures-original/GetMaintenanceByBikeId.sql.
-- Deployed by archive/scripts/00b_apply_procedure_fixes.sql; kept for reference after archiving.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.GetMaintenanceByBikeId
-- Changes:
--   * BUG (broken today): filtered the MaintenanceLog view with `[Bike] = @BikeId`, but [Bike] is the bike *name*,
--     so every call failed converting the name to int. Now queries the base tables and filters on Maintenance.BikeId.
--   * The [Bike] column was selected twice; column names no longer contain spaces.
--   * text Notes cast to varchar(max); ORDER BY Odometer, Id.
CREATE OR ALTER PROCEDURE dbo.GetMaintenanceByBikeId
    @BikeId int
AS
BEGIN
    SET NOCOUNT ON;

    SELECT mt.Id,
           mt.[Date]                                   AS OperationDate,
           b.[Name]                                    AS Bike,
           mf.[Name]                                   AS Manufacturer,
           p.[Name]                                    AS Part,
           pt.[Name]                                   AS PartType,
           mt.ActionTaken,
           mt.Odometer,
           COALESCE(CAST(mt.Notes AS varchar(max)), '') AS Notes
    FROM dbo.Maintenance AS mt
    INNER JOIN dbo.Bike         AS b  ON b.Id  = mt.BikeId
    INNER JOIN dbo.Part         AS p  ON p.Id  = mt.PartId
    INNER JOIN dbo.Manufacturer AS mf ON mf.Id = p.ManufacturerId
    INNER JOIN dbo.PartType     AS pt ON pt.Id = p.PartTypeId
    WHERE mt.BikeId = @BikeId
    ORDER BY mt.Odometer, mt.Id;
END;
GO

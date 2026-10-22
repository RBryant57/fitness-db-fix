-- Fixed version of dbo.GetPartAge (2026-10-14). The pre-fix original is archive/procedures-original/GetPartAge.sql.
-- Deployed by archive/scripts/00b_apply_procedure_fixes.sql; kept for reference after archiving.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.GetPartAge
-- Changes:
--   * The bike's current odometer is now dbo.OdometerReading (all five odometer sources). The original looked only at
--     training and recreational rides, so trainer, non-ride and bike-only miles were ignored.
--   * Duplicate result column names (two columns called Name) fixed: ManufacturerName, PartName.
--   * New MilesOnPart column (OdometerReading - PartOdometer). The OdometerReading column keeps its original name.
--   * Duplicated join/subquery replaced by TOP (1) WITH TIES; schema-qualified.
CREATE OR ALTER PROCEDURE dbo.GetPartAge
    @BikeId     int,
    @PartTypeId int
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @BikeOdometer int = dbo.OdometerReading(CAST(GETDATE() AS date), @BikeId);

    SELECT TOP (1) WITH TIES
           m.[Name]                             AS ManufacturerName,
           p.[Name]                             AS PartName,
           bp.StartDate,
           bp.OdometerReading                   AS PartOdometer,
           @BikeOdometer                        AS OdometerReading,
           @BikeOdometer - bp.OdometerReading   AS MilesOnPart
    FROM dbo.BikePart AS bp
    INNER JOIN dbo.Part         AS p ON p.Id = bp.PartId
    INNER JOIN dbo.Manufacturer AS m ON m.Id = p.ManufacturerId
    WHERE bp.BikeId    = @BikeId
      AND p.PartTypeId = @PartTypeId
      AND bp.EndDate IS NULL
    ORDER BY bp.OdometerReading;
END;
GO

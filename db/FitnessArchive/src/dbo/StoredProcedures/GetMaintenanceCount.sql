
-- dbo.GetMaintenanceCount
-- Changes:
--   * Result column named MaintenanceCount; schema-qualified.
CREATE   PROCEDURE dbo.GetMaintenanceCount
    @BikeId int
AS
BEGIN
    SET NOCOUNT ON;

    SELECT COUNT(*) AS MaintenanceCount
    FROM dbo.Maintenance AS mt
    WHERE mt.BikeId = @BikeId;
END;

GO


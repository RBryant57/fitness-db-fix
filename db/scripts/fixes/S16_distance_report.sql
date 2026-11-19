-- S16_distance_report.sql
-- S16 (decision, read-only): rides record two distances, the odometer difference (EndOdometer - StartOdometer, shown as
-- [Stated Distance]) and an optional Distance. Runs and walks have only Distance. This report shows how the two compare,
-- so you can decide which one is authoritative. It changes nothing.
--   Option A (no change): odometer = what the bike computer says; Distance = GPS distance when there is a track.
--   Option B: Distance is the true value; make it required on rides and have the views fall back to the odometer
--             only when Distance is NULL (COALESCE(Distance, EndOdometer - StartOdometer)).
-- sqlcmd -S <server> -d Fitness -E -I -i S16_distance_report.sql

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @CurrentDb sysname = DB_NAME();
IF @CurrentDb <> N'Fitness'
BEGIN
    RAISERROR(N'Connected to database %s, not Fitness. Nothing was changed.', 16, 1, @CurrentDb);
    SET NOEXEC ON;
END;
GO

SELECT N'TrainingRide' AS TableName, COUNT(*) AS [Rows], COUNT(Distance) AS WithDistance,
       CAST(AVG(CAST(EndOdometer - StartOdometer AS decimal(9, 2))) AS decimal(9, 2)) AS AvgOdometerMiles,
       CAST(AVG(Distance) AS decimal(9, 2)) AS AvgDistance,
       SUM(CASE WHEN ABS(Distance - (EndOdometer - StartOdometer)) > 1 THEN 1 ELSE 0 END) AS DifferByOverOneMile
FROM dbo.TrainingRide
UNION ALL
SELECT N'RecreationalRide', COUNT(*), COUNT(Distance),
       CAST(AVG(CAST(EndOdometer - StartOdometer AS decimal(9, 2))) AS decimal(9, 2)), CAST(AVG(Distance) AS decimal(9, 2)),
       SUM(CASE WHEN ABS(Distance - (EndOdometer - StartOdometer)) > 1 THEN 1 ELSE 0 END)
FROM dbo.RecreationalRide
UNION ALL
SELECT N'StationaryRide', COUNT(*), COUNT(Distance),
       CAST(AVG(CAST(EndOdometer - StartOdometer AS decimal(9, 2))) AS decimal(9, 2)), CAST(AVG(Distance) AS decimal(9, 2)),
       SUM(CASE WHEN ABS(Distance - (EndOdometer - StartOdometer)) > 1 THEN 1 ELSE 0 END)
FROM dbo.StationaryRide;

-- The rides where the two differ by more than a mile
SELECT TOP (50) N'TrainingRide' AS TableName, Id, [Date], EndOdometer - StartOdometer AS OdometerMiles, Distance, GpxJsonId
FROM dbo.TrainingRide WHERE ABS(Distance - (EndOdometer - StartOdometer)) > 1
UNION ALL
SELECT TOP (50) N'RecreationalRide', Id, [Date], EndOdometer - StartOdometer, Distance, GpxJsonId
FROM dbo.RecreationalRide WHERE ABS(Distance - (EndOdometer - StartOdometer)) > 1
ORDER BY TableName, [Date];
GO

SET NOEXEC OFF;
GO

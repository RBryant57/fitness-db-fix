-- dbo.TrainingRides (report view read by the API)
-- Revised 2026-11-17: Duration is now the table's computed time(0) column, not text.
--   API: the report-model property changes from string to TimeSpan (serialized as "hh:mm:ss").
-- Revised 2026-10-21.
--   * Hours / Minutes / Seconds are replaced by one column, Duration, text in the form hh:mm:ss computed from
--     StartTime and EndTime (rides of 100 hours or more show more hour digits). The RideTimeHours/Minutes/Seconds
--     columns are no longer used and can be dropped from dbo.TrainingRide (S5).
--     API: replace the Hours, Minutes and Seconds properties of the report model with a string Duration.
--   * Other columns keep their names and order.
--   * Pace no longer truncates: seconds are cast to decimal before dividing (V1). Values change by up to 1 s/mile.
--   * Speed and Pace return NULL instead of failing the whole view when a ride has zero duration or zero
--     odometer distance (V2).
--   * The join to Manufacturer is removed; nothing was selected from it (V4). Bike.ManufacturerId is NOT NULL with a
--     foreign key, so the row count is unchanged (the check below confirms it).
CREATE VIEW [dbo].[TrainingRides]
AS
SELECT tr.Id,
       tr.[Date]                                                   AS [Ride Date],
       tr.StartTime                                                AS [Starting Time],
       tr.EndTime                                                  AS [Ending Time],
       tr.Duration,
       tr.EndOdometer - tr.StartOdometer                           AS [Stated Distance],
       tr.Distance,
       (tr.EndOdometer - tr.StartOdometer) * 1.0 / NULLIF(d.Secs, 0) * 3600 AS Speed,
       CAST(d.Secs AS decimal(12, 2)) / NULLIF(tr.EndOdometer - tr.StartOdometer, 0) / 60.0 AS Pace,
       tr.MaxSpeed                                                 AS [Maximum Speed],
       tr.AverageHR                                                AS [Average HR],
       tr.MaxHR                                                    AS [Maximum HR],
       tr.AverageCadence                                           AS [Average Cadence],
       tr.ElevationGain                                            AS [Elevation Gain],
       tr.WindSpeed                                                AS [Wind Speed],
       tr.WindDirection                                            AS [Wind Direction],
       tr.Temperature,
       tr.Precipitation,
       b.Name                                                      AS [Bike Name],
       bt.Name                                                     AS [Bike Type],
       r.Name                                                      AS [Route Name],
       r.City,
       r.State,
       rt.Name                                                     AS [Route Type],
       COALESCE(tr.Notes, '')                                      AS Notes,
       CASE WHEN tr.GpxJsonId IS NULL THEN 'No' ELSE 'Yes' END     AS [GPX?]
FROM dbo.TrainingRide AS tr
CROSS APPLY (SELECT DATEDIFF(second, tr.StartTime, tr.EndTime) AS Secs) AS d
INNER JOIN dbo.Bike      AS b  ON b.Id  = tr.BikeId
INNER JOIN dbo.BikeType  AS bt ON bt.Id = b.TypeId
INNER JOIN dbo.Route     AS r  ON r.Id  = tr.RouteId
INNER JOIN dbo.RouteType AS rt ON rt.Id = r.TypeId;
GO

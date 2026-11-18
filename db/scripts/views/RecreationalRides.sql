-- dbo.RecreationalRides (report view read by the API)
-- Revised 2026-11-17: Duration, BikeDuration and RestDuration are now the table's computed time(0) columns, not text.
--   API: the report-model properties change from string to TimeSpan (serialized as "hh:mm:ss").
-- Revised 2026-11-11, following views/TrainingRides.sql.
--   * Hours / Minutes / Seconds and the Bike Hours / Minutes / Seconds are replaced by Duration (StartTime to
--     EndTime), BikeDuration (StartTime to BikeEndTime, the activity itself) and RestDuration (BikeEndTime to EndTime,
--     shown as -hh:mm:ss if BikeEndTime is after EndTime), all text hh:mm:ss (S5). API: replace those six report-model
--     properties with three strings.
--   * Speed and Pace keep their fractions (V1) and return NULL instead of failing the whole view when a row has zero
--     duration or zero distance (V2).
--   * The join to Manufacturer is removed; nothing was selected from it (V4). Bike.ManufacturerId is NOT NULL with a
--     foreign key, so the row count is unchanged.
--   * Other columns keep their names and order.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER VIEW dbo.RecreationalRides
AS
SELECT rr.Id,
       rr.[Date]                                                    AS [Ride Date],
       rr.StartTime                                                 AS [Starting Time],
       rr.EndTime                                                   AS [Ending Time],
       rr.BikeEndTime                                               AS [Bike Ending Time],
       rr.Duration,
       rr.BikeDuration,
       rr.RestDuration,
       rr.EndOdometer - rr.StartOdometer                            AS [Stated Distance],
       rr.Distance,
       (rr.EndOdometer - rr.StartOdometer) * 1.0 / NULLIF(d.ActiveSecs, 0) * 3600 AS Speed,
       CAST(d.ActiveSecs AS decimal(12, 2)) / NULLIF((rr.EndOdometer - rr.StartOdometer), 0) / 60.0 AS Pace,
       rr.MaxSpeed                                                  AS [Maximum Speed],
       (rr.EndOdometer - rr.StartOdometer) * 1.0 / NULLIF(d.Secs, 0) * 3600 AS [Overall Speed],
       CAST(d.Secs AS decimal(12, 2)) / NULLIF((rr.EndOdometer - rr.StartOdometer), 0) / 60.0 AS [Overall Pace],
       rr.AverageHR                                                 AS [Average HR],
       rr.MaxHR                                                     AS [Maximum HR],
       rr.AverageCadence                                            AS [Average Cadence],
       rr.ElevationGain                                             AS [Elevation Gain],
       rr.Wind,
       rr.Temperature,
       rr.Precipitation,
       b.Name                                                       AS [Bike Name],
       bt.Name                                                      AS [Bike Type],
       r.Name                                                       AS [Route Name],
       r.City,
       r.State,
       rt.Name                                                      AS [Route Type],
       COALESCE(rr.Notes, '')                                       AS Notes,
       CASE WHEN rr.GpxJsonId IS NULL THEN 'No' ELSE 'Yes' END      AS [GPX?]
FROM dbo.RecreationalRide AS rr
CROSS APPLY (SELECT DATEDIFF(second, rr.StartTime, rr.EndTime)     AS Secs,
                    DATEDIFF(second, rr.StartTime, rr.BikeEndTime) AS ActiveSecs) AS d
INNER JOIN dbo.Bike      AS b  ON b.Id  = rr.BikeId
INNER JOIN dbo.BikeType  AS bt ON bt.Id = b.TypeId
INNER JOIN dbo.Route     AS r  ON r.Id  = rr.RouteId
INNER JOIN dbo.RouteType AS rt ON rt.Id = r.TypeId;
GO

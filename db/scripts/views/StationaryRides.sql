-- dbo.StationaryRides (report view read by the API)
-- Revised 2026-11-17: Duration is now the table's computed time(0) column, not text.
--   API: the report-model property changes from string to TimeSpan (serialized as "hh:mm:ss").
-- Revised 2026-11-11, following views/TrainingRides.sql.
--   * Hours / Minutes / Seconds are replaced by Duration, text hh:mm:ss computed from StartTime and EndTime (S5). API:
--     replace those report-model properties with a string Duration.
--   * Speed and Pace keep their fractions (V1) and return NULL instead of failing the whole view when a row has zero
--     duration or zero distance (V2).
--   * The RIGHT OUTER JOIN is rewritten as LEFT JOINs from StationaryRide; the rows returned are the same.
--   * Other columns keep their names and order.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER VIEW dbo.StationaryRides
AS
SELECT sr.Id,
       sr.[Date]                                                    AS [Ride Date],
       sr.StartTime                                                 AS [Starting Time],
       sr.EndTime                                                   AS [Ending Time],
       sr.Duration,
       sr.EndOdometer - sr.StartOdometer                            AS Distance,
       (sr.EndOdometer - sr.StartOdometer) * 1.0 / NULLIF(d.Secs, 0) * 3600 AS Speed,
       CAST(d.Secs AS decimal(12, 2)) / NULLIF(sr.EndOdometer - sr.StartOdometer, 0) / 60.0 AS Pace,
       sr.AverageHR                                                 AS [Average HR],
       sr.MaxHR                                                     AS [Maximum HR],
       sr.AverageCadence                                            AS [Average Cadence],
       COALESCE(sr.Notes, '')                                       AS Notes,
       b.Name                                                       AS [Bike Name],
       bt.Name                                                      AS [Bike Type]
FROM dbo.StationaryRide AS sr
CROSS APPLY (SELECT DATEDIFF(second, sr.StartTime, sr.EndTime) AS Secs) AS d
LEFT JOIN dbo.Bike     AS b  ON b.Id  = sr.BikeId          -- rides on a generic trainer have no bike
LEFT JOIN dbo.BikeType AS bt ON bt.Id = b.TypeId;
GO

-- dbo.TrainingRuns (report view read by the API)
-- Revised 2026-11-17: Duration is now the table's computed time(0) column, not text.
--   API: the report-model property changes from string to TimeSpan (serialized as "hh:mm:ss").
-- Revised 2026-11-11, following views/TrainingRides.sql.
--   * Hours / Minutes / Seconds are replaced by Duration, text hh:mm:ss computed from StartTime and EndTime (S5). API:
--     replace those report-model properties with a string Duration.
--   * Speed and Pace keep their fractions (V1) and return NULL instead of failing the whole view when a row has zero
--     duration or zero distance (V2). Pace used to divide by 60 (int); it now divides by 60.0 like the other views.
--   * Other columns keep their names and order.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER VIEW dbo.TrainingRuns
AS
SELECT tr.Id,
       tr.[Date]                                                    AS [Run Date],
       tr.StartTime                                                 AS [Starting Time],
       tr.EndTime                                                   AS [Ending Time],
       tr.Duration,
       tr.Distance,
       tr.Distance / NULLIF(d.Secs, 0) * 3600                       AS Speed,
       CAST(d.Secs AS decimal(12, 2)) / NULLIF(tr.Distance, 0) / 60.0 AS Pace,
       tr.MaxSpeed                                                  AS [Maximum Speed],
       tr.AverageHR                                                 AS [Average HR],
       tr.MaxHR                                                     AS [Maximum HR],
       tr.ElevationGain                                             AS [Elevation Gain],
       tr.WindSpeed                                                 AS [Wind Speed],
       tr.WindDirection                                             AS [Wind Direction],
       tr.Temperature,
       tr.Precipitation,
       s.Name                                                       AS [Shoe Name],
       st.Name                                                      AS [Shoe Type],
       r.Name                                                       AS [Route Name],
       r.City,
       r.State,
       rt.Name                                                      AS [Route Type],
       COALESCE(tr.Notes, '')                                       AS Notes,
       CASE WHEN tr.GpxJsonId IS NULL THEN 'No' ELSE 'Yes' END      AS [GPX?]
FROM dbo.TrainingRun AS tr
CROSS APPLY (SELECT DATEDIFF(second, tr.StartTime, tr.EndTime) AS Secs) AS d
INNER JOIN dbo.Route     AS r  ON r.Id  = tr.RouteId
INNER JOIN dbo.RouteType AS rt ON rt.Id = r.TypeId
INNER JOIN dbo.Shoe      AS s  ON s.Id  = tr.ShoeId
INNER JOIN dbo.ShoeType  AS st ON st.Id = s.ShoeTypeId;
GO

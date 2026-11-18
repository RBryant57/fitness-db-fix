-- dbo.RecreationalRuns (report view read by the API)
-- Revised 2026-11-17: Duration, PathDuration and RestDuration are now the table's computed time(0) columns, not text.
--   API: the report-model properties change from string to TimeSpan (serialized as "hh:mm:ss").
-- Revised 2026-11-11, following views/TrainingRides.sql.
--   * Hours / Minutes / Seconds and the Path Hours / Minutes / Seconds are replaced by Duration (StartTime to
--     EndTime), PathDuration (StartTime to PathEndTime, the activity itself) and RestDuration (PathEndTime to EndTime,
--     shown as -hh:mm:ss if PathEndTime is after EndTime), all text hh:mm:ss (S5). API: replace those six report-model
--     properties with three strings.
--   * Speed and Pace keep their fractions (V1) and return NULL instead of failing the whole view when a row has zero
--     duration or zero distance (V2).
--   * Speed and Pace now measure the activity itself (StartTime to PathEndTime) and Overall Speed / Overall Pace the
--     whole outing (StartTime to EndTime, rest included), as in RecreationalRides. The old view had them the other way
--     round, so those four values swap for every row.
--   * Other columns keep their names and order.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER VIEW dbo.RecreationalRuns
AS
SELECT rr.Id,
       rr.[Date]                                                    AS [Run Date],
       rr.StartTime                                                 AS [Starting Time],
       rr.EndTime                                                   AS [Ending Time],
       rr.PathEndTime                                               AS [Path Ending Time],
       rr.Duration,
       rr.PathDuration,
       rr.RestDuration,
       rr.Distance,
       rr.Distance * 1.0 / NULLIF(d.ActiveSecs, 0) * 3600           AS Speed,
       CAST(d.ActiveSecs AS decimal(12, 2)) / NULLIF(rr.Distance, 0) / 60.0 AS Pace,
       rr.Distance * 1.0 / NULLIF(d.Secs, 0) * 3600                 AS [Overall Speed],
       CAST(d.Secs AS decimal(12, 2)) / NULLIF(rr.Distance, 0) / 60.0 AS [Overall Pace],
       rr.MaxSpeed                                                  AS [Maximum Speed],
       rr.AverageHR                                                 AS [Average HR],
       rr.MaxHR                                                     AS [Maximum HR],
       rr.ElevationGain                                             AS [Elevation Gain],
       rr.Wind,
       rr.Temperature,
       rr.Precipitation,
       s.Name                                                       AS [Shoe Name],
       st.Name                                                      AS [Shoe Type],
       r.Name                                                       AS [Route Name],
       r.City,
       r.State,
       rt.Name                                                      AS [Route Type],
       COALESCE(rr.Notes, '')                                       AS Notes,
       CASE WHEN rr.GpxJsonId IS NULL THEN 'No' ELSE 'Yes' END      AS [GPX?]
FROM dbo.RecreationalRun AS rr
CROSS APPLY (SELECT DATEDIFF(second, rr.StartTime, rr.EndTime)     AS Secs,
                    DATEDIFF(second, rr.StartTime, rr.PathEndTime) AS ActiveSecs) AS d
INNER JOIN dbo.Route     AS r  ON r.Id  = rr.RouteId
INNER JOIN dbo.RouteType AS rt ON rt.Id = r.TypeId
INNER JOIN dbo.Shoe      AS s  ON s.Id  = rr.ShoeId
INNER JOIN dbo.ShoeType  AS st ON st.Id = s.ShoeTypeId;
GO

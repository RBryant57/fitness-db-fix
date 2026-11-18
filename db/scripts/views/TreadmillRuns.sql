-- dbo.TreadmillRuns (report view read by the API)
-- Revised 2026-11-17: Duration is now the table's computed time(0) column, not text.
--   API: the report-model property changes from string to TimeSpan (serialized as "hh:mm:ss").
-- Revised 2026-11-11, following views/TrainingRides.sql.
--   * Hours / Minutes / Seconds are replaced by Duration, text hh:mm:ss computed from StartTime and EndTime (S5). API:
--     replace those report-model properties with a string Duration.
--   * Speed and Pace keep their fractions (V1) and return NULL instead of failing the whole view when a row has zero
--     duration or zero distance (V2).
--   * Other columns keep their names and order.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER VIEW dbo.TreadmillRuns
AS
SELECT tm.Id,
       tm.[Date]                                                    AS [Run Date],
       tm.StartTime                                                 AS [Starting Time],
       tm.EndTime                                                   AS [Ending Time],
       tm.Duration,
       tm.Distance,
       tm.Distance / NULLIF(d.Secs, 0) * 3600                       AS Speed,
       CAST(d.Secs AS decimal(12, 2)) / NULLIF(tm.Distance, 0) / 60.0 AS Pace,
       tm.AverageHR                                                 AS [Average HR],
       tm.MaxHR                                                     AS [Maximum HR],
       tm.ElevationGain                                             AS [Elevation Gain],
       s.Name                                                       AS [Shoe Name],
       st.Name                                                      AS [Shoe Type],
       COALESCE(tm.Notes, '')                                       AS Notes
FROM dbo.TreadmillRun AS tm
CROSS APPLY (SELECT DATEDIFF(second, tm.StartTime, tm.EndTime) AS Secs) AS d
INNER JOIN dbo.Shoe     AS s  ON s.Id  = tm.ShoeId
INNER JOIN dbo.ShoeType AS st ON st.Id = s.ShoeTypeId;
GO

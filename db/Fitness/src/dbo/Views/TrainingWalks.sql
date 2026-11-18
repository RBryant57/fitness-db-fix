-- dbo.TrainingWalks (report view read by the API)
-- Revised 2026-11-17: Duration is now the table's computed time(0) column, not text.
--   API: the report-model property changes from string to TimeSpan (serialized as "hh:mm:ss").
-- Revised 2026-11-11, following views/TrainingRides.sql.
--   * Hours / Minutes / Seconds are replaced by Duration, text hh:mm:ss computed from StartTime and EndTime (S5). API:
--     replace those report-model properties with a string Duration.
--   * Speed and Pace keep their fractions (V1) and return NULL instead of failing the whole view when a row has zero
--     duration or zero distance (V2). Pace used to divide by 60 (int); it now divides by 60.0 like the other views.
--   * Other columns keep their names and order.
CREATE VIEW [dbo].[TrainingWalks]
AS
SELECT tw.Id,
       tw.[Date]                                                    AS [Walk Date],
       tw.StartTime                                                 AS [Starting Time],
       tw.EndTime                                                   AS [Ending Time],
       tw.Duration,
       tw.Distance,
       tw.Distance / NULLIF(d.Secs, 0) * 3600                       AS Speed,
       CAST(d.Secs AS decimal(12, 2)) / NULLIF(tw.Distance, 0) / 60.0 AS Pace,
       tw.MaxSpeed                                                  AS [Maximum Speed],
       tw.AverageHR                                                 AS [Average HR],
       tw.MaxHR                                                     AS [Maximum HR],
       tw.ElevationGain                                             AS [Elevation Gain],
       tw.WindSpeed                                                 AS [Wind Speed],
       tw.WindDirection                                             AS [Wind Direction],
       tw.Temperature,
       tw.Precipitation,
       s.Name                                                       AS [Shoe Name],
       st.Name                                                      AS [Shoe Type],
       r.Name                                                       AS [Route Name],
       r.City,
       r.State,
       rt.Name                                                      AS [Route Type],
       COALESCE(tw.Notes, '')                                       AS Notes,
       CASE WHEN tw.GpxJsonId IS NULL THEN 'No' ELSE 'Yes' END      AS [GPX?]
FROM dbo.TrainingWalk AS tw
CROSS APPLY (SELECT DATEDIFF(second, tw.StartTime, tw.EndTime) AS Secs) AS d
INNER JOIN dbo.Route     AS r  ON r.Id  = tw.RouteId
INNER JOIN dbo.RouteType AS rt ON rt.Id = r.TypeId
INNER JOIN dbo.Shoe      AS s  ON s.Id  = tw.ShoeId
INNER JOIN dbo.ShoeType  AS st ON st.Id = s.ShoeTypeId;
GO

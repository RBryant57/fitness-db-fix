-- dbo.TrainingRides (report view read by the API)
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
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER VIEW dbo.TrainingRides
AS
SELECT tr.Id,
       tr.[Date]                                                   AS [Ride Date],
       tr.StartTime                                                AS [Starting Time],
       tr.EndTime                                                  AS [Ending Time],
       CONCAT(CASE WHEN d.Secs / 3600 < 10 THEN '0' ELSE '' END, d.Secs / 3600, ':',
              RIGHT(CONCAT('0', d.Secs % 3600 / 60), 2), ':',
              RIGHT(CONCAT('0', d.Secs % 60), 2))                  AS Duration,
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

/* ---------------------------------------------------------------------------------------------------------------
   Check BEFORE running the CREATE OR ALTER above (run this block on its own while RideTime* columns still exist).

   1. Rides where the stored duration disagrees with the times. These rows will show a Duration that differs from the
      old Hours/Minutes/Seconds. If any are deliberate (e.g. moving time entered by hand), stop and decide first.

   SELECT Id, [Date], StartTime, EndTime, RideTimeHours, RideTimeMinutes, RideTimeSeconds,
          DATEDIFF(second, StartTime, EndTime) AS NewSeconds
   FROM dbo.TrainingRide
   WHERE RideTimeHours * 3600 + RideTimeMinutes * 60 + RideTimeSeconds <> DATEDIFF(second, StartTime, EndTime);

   2. Rows that would have made the old view fail (zero duration or zero distance); they now show NULL Speed/Pace.

   SELECT Id, [Date] FROM dbo.TrainingRide
   WHERE DATEDIFF(second, StartTime, EndTime) = 0 OR EndOdometer = StartOdometer;

   3. After running it: the row count must equal the old join chain, which also joined Manufacturer.

   SELECT (SELECT COUNT(*) FROM dbo.TrainingRides) AS ViewRows,
          (SELECT COUNT(*) FROM dbo.TrainingRide t
             JOIN dbo.Bike b          ON b.Id  = t.BikeId
             JOIN dbo.BikeType bt     ON bt.Id = b.TypeId
             JOIN dbo.Route r         ON r.Id  = t.RouteId
             JOIN dbo.RouteType rt    ON rt.Id = r.TypeId
             JOIN dbo.Manufacturer m  ON m.Id  = b.ManufacturerId) AS OldJoinRows;
   --------------------------------------------------------------------------------------------------------------- */

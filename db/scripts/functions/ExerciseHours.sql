-- dbo.ExerciseHours (@StartDate, @EndDate)
-- One row per exercise entry, with its defined time (by the rules below) and its actual time (EndTime - StartTime).
--
-- Defined time is counted in 30-minute blocks:
--   LiftingSession, Stairs, TreadmillRun   every entry = 1 block (0:30:00)
--   TrainingRun                            4 miles  = 1 block
--   TrainingWalk                           2 miles  = 1 block
--   StationaryRide, TrainingRide           10 miles = 1 block
--   Run and walk miles are rounded to the nearest whole block, with a minimum of one block per entry
--   (a 3.82-mile run counts as 1 block). Rides count in 5-mile (15-minute) steps with a minimum of 30 minutes,
--   so a 15-mile ride is 1.5 blocks (0:45:00) and a 45-mile ride is 4.5 blocks (2:15:00).
--   Ride miles = EndOdometer - StartOdometer, as in dbo.MileageGoalReport. Run and walk miles = Distance.
-- Actual time = DATEDIFF(second, StartTime, EndTime). LiftingSession has no times, so its actual columns are NULL.
-- Difference = actual - defined (positive means the entry took longer than its defined time).
--
-- Pass NULL for an open-ended range. Both dates are inclusive.
-- Usage:
--   SELECT * FROM dbo.ExerciseHours('2026-01-01', '2026-12-31') ORDER BY [Date];
--
--   -- Totals by year and activity (hours as decimals)
--   SELECT YEAR([Date]) AS [Year], Activity, COUNT(*) AS Entries,
--          SUM(DefinedSeconds) / 3600.0 AS DefinedHours,
--          SUM(ActualSeconds)  / 3600.0 AS ActualHours,                        -- LiftingSession: NULL
--          SUM(CASE WHEN ActualSeconds IS NOT NULL THEN DefinedSeconds END) / 3600.0 AS DefinedHoursWithTimes,
--          SUM(DifferenceSeconds) / 3600.0 AS DifferenceHours
--   FROM dbo.ExerciseHours(NULL, NULL)
--   GROUP BY YEAR([Date]), Activity
--   ORDER BY [Year], Activity;
--
--   -- Average actual minutes per 30-minute block, by activity
--   SELECT Activity, AVG(ActualSeconds / 60.0 / Blocks) AS ActualMinutesPerBlock
--   FROM dbo.ExerciseHours(NULL, NULL) WHERE ActualSeconds IS NOT NULL GROUP BY Activity;
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER FUNCTION dbo.ExerciseHours
(
    @StartDate date,
    @EndDate   date
)
RETURNS TABLE
AS
RETURN
(
    WITH Entries AS
    (
        SELECT N'LiftingSession' AS Activity, Id, [Date], CAST(NULL AS decimal(9, 4)) AS Miles,
               CAST(1 AS decimal(5, 1)) AS Blocks, CAST(NULL AS int) AS ActualSeconds
        FROM dbo.LiftingSession
        UNION ALL
        SELECT N'Stairs', Id, [Date], NULL, 1, DATEDIFF(second, StartTime, EndTime)
        FROM dbo.Stairs
        UNION ALL
        SELECT N'TreadmillRun', Id, [Date], Distance, 1, DATEDIFF(second, StartTime, EndTime)
        FROM dbo.TreadmillRun
        UNION ALL
        SELECT N'TrainingRun', Id, [Date], Distance,
               CAST(CASE WHEN ROUND(Distance / 4.0, 0) < 1 THEN 1 ELSE ROUND(Distance / 4.0, 0) END AS int),
               DATEDIFF(second, StartTime, EndTime)
        FROM dbo.TrainingRun
        UNION ALL
        SELECT N'TrainingWalk', Id, [Date], Distance,
               CAST(CASE WHEN ROUND(Distance / 2.0, 0) < 1 THEN 1 ELSE ROUND(Distance / 2.0, 0) END AS int),
               DATEDIFF(second, StartTime, EndTime)
        FROM dbo.TrainingWalk
        UNION ALL
        SELECT N'StationaryRide', Id, [Date], EndOdometer - StartOdometer,
               CAST(CASE WHEN ROUND((EndOdometer - StartOdometer) / 5.0, 0) < 2 THEN 2
                         ELSE ROUND((EndOdometer - StartOdometer) / 5.0, 0) END / 2.0 AS decimal(5, 1)),
               DATEDIFF(second, StartTime, EndTime)
        FROM dbo.StationaryRide
        UNION ALL
        SELECT N'TrainingRide', Id, [Date], EndOdometer - StartOdometer,
               CAST(CASE WHEN ROUND((EndOdometer - StartOdometer) / 5.0, 0) < 2 THEN 2
                         ELSE ROUND((EndOdometer - StartOdometer) / 5.0, 0) END / 2.0 AS decimal(5, 1)),
               DATEDIFF(second, StartTime, EndTime)
        FROM dbo.TrainingRide
    )
    SELECT e.Activity,
           e.Id,
           e.[Date],
           e.Miles,
           e.Blocks,
           s.DefinedSeconds,
           f.Defined,
           e.ActualSeconds,
           f.Actual,
           s.DifferenceSeconds,
           f.Difference
    FROM Entries AS e
    CROSS APPLY (SELECT CAST(e.Blocks * 1800 AS int) AS DefinedSeconds,
                        e.ActualSeconds - CAST(e.Blocks * 1800 AS int) AS DifferenceSeconds) AS s
    CROSS APPLY (SELECT ABS(s.DifferenceSeconds) AS AbsDiff) AS a
    CROSS APPLY (SELECT
        -- hh:mm:ss text, e.g. 01:00:00; Difference carries a sign, e.g. -00:04:10
        CONCAT(RIGHT(CONCAT('0', s.DefinedSeconds / 3600), 2), ':',
               RIGHT(CONCAT('0', s.DefinedSeconds % 3600 / 60), 2), ':',
               RIGHT(CONCAT('0', s.DefinedSeconds % 60), 2)) AS Defined,
        CASE WHEN e.ActualSeconds IS NOT NULL THEN
        CONCAT(RIGHT(CONCAT('0', e.ActualSeconds / 3600), 2), ':',
               RIGHT(CONCAT('0', e.ActualSeconds % 3600 / 60), 2), ':',
               RIGHT(CONCAT('0', e.ActualSeconds % 60), 2)) END AS Actual,
        CASE WHEN s.DifferenceSeconds IS NOT NULL THEN
        CONCAT(CASE WHEN s.DifferenceSeconds < 0 THEN '-' ELSE '+' END,
               RIGHT(CONCAT('0', a.AbsDiff / 3600), 2), ':',
               RIGHT(CONCAT('0', a.AbsDiff % 3600 / 60), 2), ':',
               RIGHT(CONCAT('0', a.AbsDiff % 60), 2)) END AS Difference) AS f
    WHERE (@StartDate IS NULL OR e.[Date] >= @StartDate)
      AND (@EndDate   IS NULL OR e.[Date] <  DATEADD(day, 1, @EndDate))
);
GO

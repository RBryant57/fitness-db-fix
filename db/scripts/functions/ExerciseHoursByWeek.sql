-- dbo.ExerciseHoursByWeek (@StartDate, @EndDate)
-- One row per week (Monday to Sunday) that has at least one exercise entry, built on dbo.ExerciseHours.
-- Weeks with no entries are not returned. Hours are decimals; the *Text columns are hh:mm:ss.
--   DefinedHours       all entries, including lifting (defined only)
--   LiftingHours       the lifting part of DefinedHours
--   DefinedHoursTimed  entries that have start and end times (everything except lifting)
--   ActualHours        actual time of the timed entries
--   DifferenceHours    ActualHours - DefinedHoursTimed
-- The Monday is worked out from day numbers (1900-01-01 was a Monday), so it doesn't depend on SET DATEFIRST.
-- @StartDate and @EndDate filter entries by their date (both inclusive; NULL = open). To get whole weeks,
-- pass a Monday and a Sunday.
-- Usage:
--   SELECT * FROM dbo.ExerciseHoursByWeek('2026-01-01', '2026-12-31') ORDER BY WeekStart;
--   SELECT YEAR(WeekStart) AS [Year], AVG(DefinedHours) AS AvgDefinedHoursPerActiveWeek
--   FROM dbo.ExerciseHoursByWeek(NULL, NULL) GROUP BY YEAR(WeekStart) ORDER BY [Year];
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER FUNCTION dbo.ExerciseHoursByWeek
(
    @StartDate date,
    @EndDate   date
)
RETURNS TABLE
AS
RETURN
(
    WITH Weeks AS
    (
        SELECT DATEADD(day, -(DATEDIFF(day, '19000101', CAST(e.[Date] AS date)) % 7), CAST(e.[Date] AS date)) AS WeekStart,
               e.Activity, e.DefinedSeconds, e.ActualSeconds
        FROM dbo.ExerciseHours(@StartDate, @EndDate) AS e
    ),
    Totals AS
    (
        SELECT WeekStart,
               COUNT(*) AS Entries,
               SUM(DefinedSeconds) AS DefinedSeconds,
               SUM(CASE WHEN ActualSeconds IS NULL THEN DefinedSeconds ELSE 0 END) AS LiftingSeconds,
               SUM(CASE WHEN ActualSeconds IS NOT NULL THEN DefinedSeconds ELSE 0 END) AS DefinedSecondsTimed,
               COALESCE(SUM(ActualSeconds), 0) AS ActualSeconds
        FROM Weeks
        GROUP BY WeekStart
    )
    SELECT t.WeekStart,
           DATEADD(day, 6, t.WeekStart) AS WeekEnd,
           t.Entries,
           CAST(t.DefinedSeconds      / 3600.0 AS decimal(9, 2)) AS DefinedHours,
           CAST(t.LiftingSeconds      / 3600.0 AS decimal(9, 2)) AS LiftingHours,
           CAST(t.DefinedSecondsTimed / 3600.0 AS decimal(9, 2)) AS DefinedHoursTimed,
           CAST(t.ActualSeconds       / 3600.0 AS decimal(9, 2)) AS ActualHours,
           CAST((t.ActualSeconds - t.DefinedSecondsTimed) / 3600.0 AS decimal(9, 2)) AS DifferenceHours,
           x.DefinedText, x.ActualText, x.DifferenceText
    FROM Totals AS t
    CROSS APPLY (SELECT t.ActualSeconds - t.DefinedSecondsTimed AS Diff) AS d
    CROSS APPLY (SELECT
        CONCAT(RIGHT(CONCAT('0', t.DefinedSeconds / 3600), 2), ':', RIGHT(CONCAT('0', t.DefinedSeconds % 3600 / 60), 2), ':',
               RIGHT(CONCAT('0', t.DefinedSeconds % 60), 2)) AS DefinedText,
        CONCAT(RIGHT(CONCAT('0', t.ActualSeconds / 3600), 2), ':', RIGHT(CONCAT('0', t.ActualSeconds % 3600 / 60), 2), ':',
               RIGHT(CONCAT('0', t.ActualSeconds % 60), 2)) AS ActualText,
        CONCAT(CASE WHEN d.Diff < 0 THEN '-' ELSE '+' END,
               RIGHT(CONCAT('0', ABS(d.Diff) / 3600), 2), ':', RIGHT(CONCAT('0', ABS(d.Diff) % 3600 / 60), 2), ':',
               RIGHT(CONCAT('0', ABS(d.Diff) % 60), 2)) AS DifferenceText) AS x
);
GO

-- Fixed version of dbo.GetLastEntries (2026-10-14). The pre-fix original is archive/procedures-original/GetLastEntries.sql.
-- Deployed by archive/scripts/00b_apply_procedure_fixes.sql; kept for reference after archiving.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.GetLastEntries
-- Changes:
--   * SELECT * replaced by explicit columns; schema-qualified.
--   * Stairs added ("Last Stair Session") -- it was the only activity table missing from the list.
CREATE OR ALTER PROCEDURE dbo.GetLastEntries
AS
BEGIN
    SET NOCOUNT ON;

    SELECT x.ActivityDate, x.Activity
    FROM (
        SELECT (SELECT MAX(t.[Date])    FROM dbo.LiftingSession   AS t) AS ActivityDate, N'Last Lifting Session'   AS Activity
        UNION ALL SELECT (SELECT MAX(t.StartTime) FROM dbo.RecreationalRide AS t), N'Last Recreational Ride'
        UNION ALL SELECT (SELECT MAX(t.StartTime) FROM dbo.RecreationalRun  AS t), N'Last Recreational Run'
        UNION ALL SELECT (SELECT MAX(t.StartTime) FROM dbo.RecreationalWalk AS t), N'Last Recreational Walk'
        UNION ALL SELECT (SELECT MAX(t.StartTime) FROM dbo.StationaryRide   AS t), N'Last Stationary Ride'
        UNION ALL SELECT (SELECT MAX(t.StartTime) FROM dbo.TrainingRide     AS t), N'Last Training Ride'
        UNION ALL SELECT (SELECT MAX(t.StartTime) FROM dbo.TrainingRun      AS t), N'Last Training Run'
        UNION ALL SELECT (SELECT MAX(t.StartTime) FROM dbo.TrainingWalk     AS t), N'Last Training Walk'
        UNION ALL SELECT (SELECT MAX(t.StartTime) FROM dbo.TreadmillRun     AS t), N'Last Treadmill Run'
        UNION ALL SELECT (SELECT MAX(t.StartTime) FROM dbo.Stairs           AS t), N'Last Stair Session'
        UNION ALL SELECT (SELECT MAX(t.[Date])    FROM dbo.[Weight]         AS t), N'Last Weight Reading'
    ) AS x
    WHERE x.ActivityDate IS NOT NULL
    ORDER BY x.ActivityDate DESC;
END;
GO

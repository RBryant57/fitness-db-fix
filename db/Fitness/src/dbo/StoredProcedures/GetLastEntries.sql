-- Shows the most recent entry date for each activity table.
-- Live procedure (not archived). Same definition as db/scripts/procedures/GetLastEntries.sql.
-- dbo.GetLastEntries
-- Changes:
--   * SELECT * replaced by explicit columns; schema-qualified.
--   * Stairs added ("Last Stair Session") -- it was the only activity table missing from the list.
CREATE PROCEDURE [dbo].[GetLastEntries]
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

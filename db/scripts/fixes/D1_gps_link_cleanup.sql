-- D1_gps_link_cleanup.sql
-- Data clean-up: ten TrainingRides are linked to a GpxJson row that is an exact copy of another ride's track.
--   Rides 687, 689, 691, 692, 694, 704, 706, 711 and 713 carry the NEXT ride's track (same points, same times).
--   Ride 686 carries ride 685's track. Its Date, StartTime and EndTime are also copies of ride 685's, but its odometer
--   (2210-2220), cadence, wind, temperature and precipitation differ, so it is a real ride on an unknown day.
-- The archived GPX XML (archive.TrainingRideGPX) has the same wrong tracks, so the right ones no longer exist anywhere.
--
-- What it does: unlinks each of those rides (GpxJsonId = NULL, so the reports show GPX? = No) and deletes the ten
-- duplicate GpxJson rows. Every ride is kept. Each row is checked first: the ride must point at the expected GpxJson
-- row, that row must be byte-for-byte identical to the other ride's track, and nothing else may use it.
-- Ride 686's date and times are left as they are; the end of this script shows how to correct them if you know them.
--
-- @Apply = 0 lists each ride and its state; @Apply = 1 makes the changes, in one transaction. Safe to re-run.
-- sqlcmd -S <server> -d Fitness -E -I -b -i D1_gps_link_cleanup.sql

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @CurrentDb sysname = DB_NAME();
IF @CurrentDb <> N'Fitness'
BEGIN
    RAISERROR(N'Connected to database %s, not Fitness. Nothing was changed.', 16, 1, @CurrentDb);
    SET NOEXEC ON;
END;
GO

DECLARE @Apply bit = 0;   -- 0 = list only, 1 = unlink and delete

DECLARE @Map TABLE (RideId int PRIMARY KEY, WrongGpxId int, SameAsGpxId int, State nvarchar(40) NULL);
INSERT @Map (RideId, WrongGpxId, SameAsGpxId) VALUES
    (687, 67, 68),
    (689, 69, 70),
    (691, 71, 73),
    (692, 72, 73),
    (694, 74, 75),
    (704, 84, 85),
    (706, 86, 87),
    (711, 91, 92),
    (713, 93, 94),
    (686, 66, 65);

UPDATE m SET State =
    CASE WHEN NOT EXISTS (SELECT 1 FROM dbo.GpxJson AS g WHERE g.Id = m.WrongGpxId)
              AND EXISTS (SELECT 1 FROM dbo.TrainingRide AS r WHERE r.Id = m.RideId AND r.GpxJsonId IS NULL) THEN N'already done'
         WHEN NOT EXISTS (SELECT 1 FROM dbo.TrainingRide AS r WHERE r.Id = m.RideId AND r.GpxJsonId = m.WrongGpxId) THEN N'RIDE NOT LINKED AS EXPECTED'
         WHEN NOT EXISTS (SELECT 1 FROM dbo.GpxJson AS a JOIN dbo.GpxJson AS b ON b.Id = m.SameAsGpxId
                          WHERE a.Id = m.WrongGpxId AND CAST(a.GpsData AS nvarchar(max)) = CAST(b.GpsData AS nvarchar(max))) THEN N'TRACKS DIFFER'
         WHEN EXISTS (SELECT 1 FROM dbo.TrainingRide     WHERE GpxJsonId = m.WrongGpxId AND Id <> m.RideId)
           OR EXISTS (SELECT 1 FROM dbo.TrainingRun      WHERE GpxJsonId = m.WrongGpxId)
           OR EXISTS (SELECT 1 FROM dbo.TrainingWalk     WHERE GpxJsonId = m.WrongGpxId)
           OR EXISTS (SELECT 1 FROM dbo.RecreationalRide WHERE GpxJsonId = m.WrongGpxId)
           OR EXISTS (SELECT 1 FROM dbo.RecreationalRun  WHERE GpxJsonId = m.WrongGpxId)
           OR EXISTS (SELECT 1 FROM dbo.RecreationalWalk WHERE GpxJsonId = m.WrongGpxId) THEN N'GPX ROW USED ELSEWHERE'
         ELSE N'to fix' END
FROM @Map AS m;

SELECT m.RideId, r.[Date], r.StartTime, m.WrongGpxId, m.SameAsGpxId, m.State
FROM @Map AS m LEFT JOIN dbo.TrainingRide AS r ON r.Id = m.RideId
ORDER BY m.RideId;

IF EXISTS (SELECT 1 FROM @Map WHERE State NOT IN (N'to fix', N'already done'))
BEGIN
    RAISERROR(N'Some rides are not in the expected state (see above). Nothing was changed.', 16, 1);
    RETURN;
END;

DECLARE @Count int = (SELECT COUNT(*) FROM @Map WHERE State = N'to fix');
IF @Apply = 0
BEGIN
    PRINT CONCAT(N'Nothing changed. ', @Count, N' ride(s) to unlink; set @Apply = 1 to make the changes.');
    RETURN;
END;

BEGIN TRY
    BEGIN TRANSACTION;
    UPDATE r SET GpxJsonId = NULL
    FROM dbo.TrainingRide AS r JOIN @Map AS m ON m.RideId = r.Id AND m.State = N'to fix';
    DELETE g
    FROM dbo.GpxJson AS g JOIN @Map AS m ON m.WrongGpxId = g.Id AND m.State = N'to fix';
    COMMIT;
    PRINT CONCAT(N'Unlinked ', @Count, N' ride(s) and deleted their duplicate GpxJson rows.');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    THROW;
END CATCH;

PRINT N'Ride 686 still has ride 685''s date and times. If you know the real ones:';
PRINT N'   UPDATE dbo.TrainingRide SET [Date] = ''yyyy-mm-dd'', StartTime = ''yyyy-mm-dd hh:mm:ss'', EndTime = ''yyyy-mm-dd hh:mm:ss'' WHERE Id = 686;';
GO

SET NOEXEC OFF;
GO

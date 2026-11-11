-- The highest odometer reading recorded for a bike on or before a date.
-- Live function (stays in dbo). Fixed 2026-10-14; deployed by 00b_apply_procedure_fixes.sql.
-- dbo.OdometerReading
-- Changes:
--   * Five variables + a table variable replaced by one MAX over a VALUES list (the function is now
--     eligible for scalar UDF inlining once the database is at compatibility level 150+).
--   * @Date is now `date` (callers passing GETDATE() still get "everything up to today").
--   * Same five sources as before: training, recreational and stationary rides, non-ride and bike-only miles.
CREATE FUNCTION [dbo].[OdometerReading]
(
    @Date   date,
    @BikeId int
)
RETURNS int
AS
BEGIN
    RETURN COALESCE((
        SELECT MAX(v.Reading)
        FROM (VALUES
            ((SELECT MAX(x.EndOdometer) FROM dbo.RecreationalRide AS x WHERE x.BikeId = @BikeId AND x.[Date] <= @Date)),
            ((SELECT MAX(x.EndOdometer) FROM dbo.TrainingRide     AS x WHERE x.BikeId = @BikeId AND x.[Date] <= @Date)),
            ((SELECT MAX(x.EndOdometer) FROM dbo.StationaryRide   AS x WHERE x.BikeId = @BikeId AND x.[Date] <= @Date)),
            ((SELECT MAX(x.EndOdometer) FROM dbo.NonRideMiles     AS x WHERE x.BikeId = @BikeId AND x.[Date] <= @Date)),
            ((SELECT MAX(x.EndOdometer) FROM dbo.BikeOnlyMiles    AS x WHERE x.BikeId = @BikeId AND x.[Date] <= @Date))
        ) AS v(Reading)
    ), 0);
END;
GO

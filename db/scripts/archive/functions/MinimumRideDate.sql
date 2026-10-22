-- Fixed version of dbo.MinimumRideDate (2026-10-14). The pre-fix original is archive/functions-original/MinimumRideDate.sql.
-- Deployed by archive/scripts/00b_apply_procedure_fixes.sql; kept for reference after archiving.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.MinimumRideDate
-- Changes:
--   * Two lookups + IF collapsed into one query over both ride tables.
--   * Date parameters are now `date`; range inclusive of the whole @EndDate day.
--   * BUG: each table's MIN was defaulted to @StartDate before the two were compared, so when only one of the two ride
--     tables had rides in the range the function returned @StartDate instead of the real earliest ride. Fixed.
--   * Kept: returns @StartDate when the bike has no rides in the range at all; return type still datetime.
CREATE OR ALTER FUNCTION dbo.MinimumRideDate
(
    @StartDate date,
    @EndDate   date,
    @BikeId    int
)
RETURNS datetime
AS
BEGIN
    RETURN COALESCE((
        SELECT MIN(r.RideDate)
        FROM (
            SELECT tr.[Date] AS RideDate FROM dbo.TrainingRide AS tr
            WHERE tr.BikeId = @BikeId AND tr.[Date] >= @StartDate AND tr.[Date] < DATEADD(day, 1, @EndDate)
            UNION ALL
            SELECT rr.[Date] FROM dbo.RecreationalRide AS rr
            WHERE rr.BikeId = @BikeId AND rr.[Date] >= @StartDate AND rr.[Date] < DATEADD(day, 1, @EndDate)
        ) AS r
    ), CAST(@StartDate AS datetime));
END;
GO

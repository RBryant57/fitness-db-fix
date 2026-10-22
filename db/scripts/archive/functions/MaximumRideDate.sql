-- Fixed version of dbo.MaximumRideDate (2026-10-14). The pre-fix original is archive/functions-original/MaximumRideDate.sql.
-- Deployed by archive/scripts/00b_apply_procedure_fixes.sql; kept for reference after archiving.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.MaximumRideDate
-- Changes:
--   * Two lookups + IF collapsed into one query over both ride tables.
--   * Date parameters are now `date`; range inclusive of the whole @EndDate day.
--   * Kept: returns @StartDate when the bike has no rides in the range; return type still datetime.
CREATE OR ALTER FUNCTION dbo.MaximumRideDate
(
    @StartDate date,
    @EndDate   date,
    @BikeId    int
)
RETURNS datetime
AS
BEGIN
    RETURN COALESCE((
        SELECT MAX(r.RideDate)
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

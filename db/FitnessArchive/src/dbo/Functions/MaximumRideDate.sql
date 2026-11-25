
-- dbo.MaximumRideDate
-- Changes:
--   * Two lookups + IF collapsed into one query over both ride tables.
--   * Date parameters are now `date`; range inclusive of the whole @EndDate day.
--   * Kept: returns @StartDate when the bike has no rides in the range; return type still datetime.
CREATE   FUNCTION dbo.MaximumRideDate
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


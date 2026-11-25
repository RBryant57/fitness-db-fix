
-- dbo.GetMilesByDateByShoeByRunType
-- Changes:
--   * BUG: int variables truncated decimal Distance sums. Now decimal(12,4).
--   * Unknown type raises an error; clamp removed; optional, inclusive date range; result column named Miles.
CREATE   PROCEDURE dbo.GetMilesByDateByShoeByRunType
    @StartDate date = NULL,
    @EndDate   date = NULL,
    @ShoeId    int,
    @RunType   int
AS
BEGIN
    SET NOCOUNT ON;

    IF @RunType IS NULL OR @RunType NOT IN (1, 2)
        THROW 50009, N'Unknown run type (expected 1 or 2).', 1;

    DECLARE @EndExclusive date = DATEADD(day, 1, @EndDate);

    IF @RunType = 1
        SELECT CAST(COALESCE(SUM(x.Distance), 0) AS decimal(12,4)) AS Miles
        FROM dbo.TrainingRun AS x
        WHERE x.ShoeId = @ShoeId AND (@StartDate IS NULL OR x.[Date] >= @StartDate) AND (@EndDate IS NULL OR x.[Date] < @EndExclusive);
    ELSE
        SELECT CAST(COALESCE(SUM(x.Distance), 0) AS decimal(12,4)) AS Miles
        FROM dbo.RecreationalRun AS x
        WHERE x.ShoeId = @ShoeId AND (@StartDate IS NULL OR x.[Date] >= @StartDate) AND (@EndDate IS NULL OR x.[Date] < @EndExclusive);
END;

GO


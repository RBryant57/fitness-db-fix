
-- dbo.GetMilesByDateByRunType
-- Changes:
--   * BUG: totals were stored in `int` variables, so every decimal Distance sum was truncated to whole miles.
--     Now returns decimal(12,4).
--   * Unknown @RunType raises an error (previously returned 0); optional, inclusive date range; result column named Miles.
--   Run types (unchanged): 1 training, 2 recreational.
CREATE   PROCEDURE dbo.GetMilesByDateByRunType
    @StartDate date = NULL,
    @EndDate   date = NULL,
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
        WHERE (@StartDate IS NULL OR x.[Date] >= @StartDate) AND (@EndDate IS NULL OR x.[Date] < @EndExclusive);
    ELSE
        SELECT CAST(COALESCE(SUM(x.Distance), 0) AS decimal(12,4)) AS Miles
        FROM dbo.RecreationalRun AS x
        WHERE (@StartDate IS NULL OR x.[Date] >= @StartDate) AND (@EndDate IS NULL OR x.[Date] < @EndExclusive);
END;

GO


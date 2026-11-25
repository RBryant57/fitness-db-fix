
-- dbo.GetMilesByShoeByRunType
-- Changes:
--   * BUG: a `GRANT EXECUTE ON [dbo].[GetMilesByBikeByRideType] ...` (wrong object) was pasted inside the body after a
--     commented-out END, so it ran on every call. Removed.
--   * BUG: int variables truncated decimal Distance sums. Now decimal(12,4).
--   * Unknown type raises an error; result column named Miles.
CREATE   PROCEDURE dbo.GetMilesByShoeByRunType
    @ShoeId  int,
    @RunType int
AS
BEGIN
    SET NOCOUNT ON;

    IF @RunType IS NULL OR @RunType NOT IN (1, 2)
        THROW 50009, N'Unknown run type (expected 1 or 2).', 1;

    IF @RunType = 1
        SELECT CAST(COALESCE(SUM(x.Distance), 0) AS decimal(12,4)) AS Miles
        FROM dbo.TrainingRun AS x
        WHERE x.ShoeId = @ShoeId;
    ELSE
        SELECT CAST(COALESCE(SUM(x.Distance), 0) AS decimal(12,4)) AS Miles
        FROM dbo.RecreationalRun AS x
        WHERE x.ShoeId = @ShoeId;
END;

GO


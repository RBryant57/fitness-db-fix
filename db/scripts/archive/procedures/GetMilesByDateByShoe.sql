-- Fixed version of dbo.GetMilesByDateByShoe (2026-10-14). The pre-fix original is archive/procedures-original/GetMilesByDateByShoe.sql.
-- Deployed by archive/scripts/00b_apply_procedure_fixes.sql; kept for reference after archiving.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.GetMilesByDateByShoe
-- Changes:
--   * BUG: two `GRANT EXECUTE` statements were pasted inside the body (no GO) and ran on every call. Removed.
--   * BUG: int variables truncated every decimal Distance sum, and stair miles used integer division
--     (SUM(ElevationGain) / 5280), so anything under a full vertical mile counted as 0. Now decimal arithmetic.
--   * Two duplicated branches (with / without dates) merged; @StartDate and @EndDate are independently optional.
--   * Result column named Miles (decimal(12,4)).
CREATE OR ALTER PROCEDURE dbo.GetMilesByDateByShoe
    @StartDate date = NULL,
    @EndDate   date = NULL,
    @ShoeId    int
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @EndExclusive date = DATEADD(day, 1, @EndDate);

    SELECT CAST(
          COALESCE((SELECT SUM(x.Distance) FROM dbo.TrainingRun      AS x WHERE x.ShoeId = @ShoeId AND (@StartDate IS NULL OR x.[Date] >= @StartDate) AND (@EndDate IS NULL OR x.[Date] < @EndExclusive)), 0)
        + COALESCE((SELECT SUM(x.Distance) FROM dbo.TrainingWalk     AS x WHERE x.ShoeId = @ShoeId AND (@StartDate IS NULL OR x.[Date] >= @StartDate) AND (@EndDate IS NULL OR x.[Date] < @EndExclusive)), 0)
        + COALESCE((SELECT SUM(x.Distance) FROM dbo.RecreationalRun  AS x WHERE x.ShoeId = @ShoeId AND (@StartDate IS NULL OR x.[Date] >= @StartDate) AND (@EndDate IS NULL OR x.[Date] < @EndExclusive)), 0)
        + COALESCE((SELECT SUM(x.Distance) FROM dbo.RecreationalWalk AS x WHERE x.ShoeId = @ShoeId AND (@StartDate IS NULL OR x.[Date] >= @StartDate) AND (@EndDate IS NULL OR x.[Date] < @EndExclusive)), 0)
        + COALESCE((SELECT SUM(x.Distance) FROM dbo.TreadmillRun     AS x WHERE x.ShoeId = @ShoeId AND (@StartDate IS NULL OR x.[Date] >= @StartDate) AND (@EndDate IS NULL OR x.[Date] < @EndExclusive)), 0)
        + COALESCE((SELECT SUM(x.ElevationGain) / 5280.0 FROM dbo.Stairs AS x WHERE x.ShoeId = @ShoeId AND (@StartDate IS NULL OR x.[Date] >= @StartDate) AND (@EndDate IS NULL OR x.[Date] < @EndExclusive)), 0)
        AS decimal(12,4)) AS Miles;
END;
GO

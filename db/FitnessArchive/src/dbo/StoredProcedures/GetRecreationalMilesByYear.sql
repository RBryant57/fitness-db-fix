
-- dbo.GetRecreationalMilesByYear
-- Changes:
--   * YEAR([Date]) = @Year (non-SARGable) replaced by a date range; @Year NULL also means "all years".
--   * Result column named Miles; schema-qualified.
CREATE   PROCEDURE dbo.GetRecreationalMilesByYear
    @Year int = 0
AS
BEGIN
    SET NOCOUNT ON;

    -- Bounds computed up front: DATEFROMPARTS(0, 1, 1) would raise an error, and T-SQL does not guarantee
    -- short-circuit evaluation of OR, so the "all years" case must not reach DATEFROMPARTS.
    DECLARE @From date = CASE WHEN COALESCE(@Year, 0) = 0 THEN NULL ELSE DATEFROMPARTS(@Year, 1, 1) END;
    DECLARE @To   date = DATEADD(year, 1, @From);

    SELECT COALESCE(SUM(x.EndOdometer - x.StartOdometer), 0) AS Miles
    FROM dbo.RecreationalRide AS x
    WHERE (@From IS NULL OR (x.[Date] >= @From AND x.[Date] < @To))
    OPTION (RECOMPILE);
END;

GO



-- dbo.ToDecimalHours
-- Changes:
--   * BUG: `RETURNS decimal` with no scale is decimal(18,0), so 1 h 30 m returned 2 instead of 1.5.
--     Now returns decimal(9,4).
CREATE   FUNCTION dbo.ToDecimalHours
(
    @Hours   int,
    @Minutes int
)
RETURNS decimal(9,4)
AS
BEGIN
    RETURN CAST(@Hours AS decimal(9,4)) + CAST(@Minutes AS decimal(9,4)) / 60.0;
END;

GO


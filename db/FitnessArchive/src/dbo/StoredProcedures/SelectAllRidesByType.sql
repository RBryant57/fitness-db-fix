
-- dbo.SelectAllRidesByType
-- Changes:
--   * Was a copy of SelectAllRidesByTypeByDate without the WHERE clause (3,600 characters duplicated, and the two had
--     already drifted: one returned Notes raw, the other coalesced). Now delegates to SelectAllRidesByTypeByDate with
--     no date limits, so both return exactly the same columns. See that procedure for the column changes.
CREATE   PROCEDURE dbo.SelectAllRidesByType
    @RideType int
AS
BEGIN
    SET NOCOUNT ON;

    EXEC dbo.SelectAllRidesByTypeByDate @RideType = @RideType, @StartDate = NULL, @EndDate = NULL;
END;

GO


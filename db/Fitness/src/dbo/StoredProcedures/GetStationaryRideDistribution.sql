-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 12/22/12
-- Description:	Retrieves the stationary ride/miles distribution
--				for the given time period.
-- =============================================
CREATE PROCEDURE [dbo].[GetStationaryRideDistribution]

	@StartDate				datetime,
	@EndDate				datetime,
	@Type					int
	 
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	IF @Type = 1
		BEGIN

			SELECT MONTH([Date]) AS 'Month Number', DATENAME(MONTH, [Date]) AS 'Month', COUNT(Id) AS 'Rides' FROM StationaryRide
				WHERE [Date] BETWEEN @StartDate AND @EndDate
			GROUP BY MONTH([Date]), DATENAME(MONTH, [Date])
			ORDER BY MONTH([Date])

		END

	IF @Type = 2
		BEGIN
			
			SELECT MONTH([Date]) AS 'Month Number', DATENAME(MONTH, [Date]) AS 'Month', SUM(EndOdometer - StartOdometer) AS 'Miles' FROM StationaryRide
				WHERE [Date] BETWEEN @StartDate AND @EndDate
			GROUP BY MONTH([Date]), DATENAME(MONTH, [Date])
			ORDER BY MONTH([Date])

		END

END

GO


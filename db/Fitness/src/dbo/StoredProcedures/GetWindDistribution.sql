




-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 5/5/08
-- Description:	Retrieves the wind direction distribution
--				for the given time period.
-- =============================================
CREATE PROCEDURE [dbo].[GetWindDistribution]

	@StartDate				datetime,
	@EndDate				datetime
	 
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

		SELECT WindDirection, COUNT(*) AS 'Days' FROM TrainingRide
			WHERE [Date] BETWEEN @StartDate AND @EndDate
			GROUP BY WindDirection

		UNION ALL

		SELECT WindDirection, COUNT(*) AS 'Days' FROM TrainingRun
			WHERE [Date] BETWEEN @StartDate AND @EndDate
			GROUP BY WindDirection

END

GO







-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 5/5/08
-- Description:	Retrieves the number of days with precipitation
--				for the given time period.
-- =============================================
CREATE PROCEDURE [dbo].[GetRainDays]

	@StartDate				datetime,
	@EndDate				datetime
	 
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

		DECLARE @RideRain		int
		DECLARE @RunRain		int

		SET @RideRain = COALESCE((SELECT COUNT(*) FROM TrainingRide
							WHERE [Date] BETWEEN @StartDate AND @EndDate
							AND Precipitation = 'True'), 0)

		SET @RunRain = COALESCE((SELECT COUNT(*) FROM TrainingRun
							WHERE [Date] BETWEEN @StartDate AND @EndDate
							AND Precipitation = 'True'), 0)

		SELECT @RideRain + @RunRain

END

GO


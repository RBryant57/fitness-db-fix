




-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 5/3/08
-- Description:	Retrieves the average wind speed.
-- =============================================
CREATE PROCEDURE [dbo].[GetAverageWindSpeed]

	@StartDate				datetime,
	@EndDate				datetime
	 
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

		DECLARE @RideWind		float
		DECLARE @RunWind		float
		DECLARE @TotalWind		float
		DECLARE @RideCount		float
		DECLARE @RunCount		float
		DECLARE @TotalCount		float

		DECLARE @AverageWind	float

		SET @RideWind = COALESCE((SELECT SUM(WindSpeed) FROM TrainingRide
							WHERE [Date] BETWEEN @StartDate AND @EndDate), 0)

		SET @RunWind = COALESCE((SELECT SUM(WindSpeed) FROM TrainingRun
							WHERE [Date] BETWEEN @StartDate AND @EndDate), 0)

		SET @TotalWind = @RideWind + @RunWind

	
		SET @RideCount = COALESCE((SELECT COUNT(*) FROM TrainingRide
							WHERE [Date] BETWEEN @StartDate AND @EndDate), 0)

		SET @RunCount = COALESCE((SELECT COUNT(*) FROM TrainingRun
							WHERE [Date] BETWEEN @StartDate AND @EndDate), 0)

		SET @TotalCount = @RideCount + @RunCount


		
		IF (@TotalWind = 0 AND @TotalCount = 0)
			BEGIN
				SET @AverageWind = 0
			END
		ELSE
			BEGIN
				SET @AverageWind = (@TotalWind/@TotalCount)
			END

		SELECT @AverageWind

END

GO


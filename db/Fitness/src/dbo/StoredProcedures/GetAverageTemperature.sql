




-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 5/3/08
-- Description:	Retrieves the average temperature.
-- =============================================
CREATE PROCEDURE [dbo].[GetAverageTemperature]

	@StartDate				datetime,
	@EndDate				datetime
	 
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

		DECLARE @RideTemp		float
		DECLARE @RunTemp		float
		DECLARE @TotalTemp		float
		DECLARE @RideCount		float
		DECLARE @RunCount		float
		DECLARE @TotalCount		float

		DECLARE @AverageTemp	float

		SET @RideTemp = COALESCE((SELECT SUM(Temperature) FROM TrainingRide
							WHERE [Date] BETWEEN @StartDate AND @EndDate), 0)

		SET @RunTemp = COALESCE((SELECT SUM(Temperature) FROM TrainingRun
							WHERE [Date] BETWEEN @StartDate AND @EndDate), 0)

		SET @TotalTemp = @RideTemp + @RunTemp

	
		SET @RideCount = COALESCE((SELECT COUNT(*) FROM TrainingRide
							WHERE [Date] BETWEEN @StartDate AND @EndDate), 0)

		SET @RunCount = COALESCE((SELECT COUNT(*) FROM TrainingRun
							WHERE [Date] BETWEEN @StartDate AND @EndDate), 0)

		SET @TotalCount = @RideCount + @RunCount


		
		IF (@TotalTemp = 0 AND @TotalCount = 0)
			BEGIN
				SET @AverageTemp = 0
			END
		ELSE
			BEGIN
				SET @AverageTemp = (@TotalTemp/@TotalCount)
			END

		SELECT @AverageTemp

END

GO


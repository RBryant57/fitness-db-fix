




-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 4/4/08
-- Description:	Retrieves the average weekly hours spent
--				exercising
-- =============================================
CREATE PROCEDURE [dbo].[GetAverageGymHours]

	@StartDate				datetime,
	@EndDate				datetime
	 
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

		DECLARE @RideHours				float
		DECLARE	@StationaryRideHours	float
		DECLARE @RunHours				float
		DECLARE @TreadmillHours			float
		DECLARE @LiftHours				float
		DECLARE @StairsHours			float

		DECLARE @Divisor				float

			-- Set the divisor by the number of weeks between the dates
			SET @Divisor = DATEDIFF(week, @StartDate, @EndDate)
				-- If the number of weeks is 0, use a fraction based on the number of days
				IF @Divisor = 0
					BEGIN
						SET @Divisor = DATEDIFF(day, @StartDate, @EndDate)
						SET @Divisor = @Divisor / 7
					END
		
		
			SET @RideHours = COALESCE((SELECT SUM(EndOdometer - StartOdometer) FROM TrainingRide
								WHERE [Date] BETWEEN @StartDate AND @EndDate), 0)

			SET @StationaryRideHours = COALESCE((SELECT SUM(EndOdometer - StartOdometer) FROM StationaryRide
								WHERE [Date] BETWEEN @StartDate AND @EndDate), 0)

			SET @RunHours = COALESCE((SELECT SUM(Distance) FROM TrainingRun
								WHERE [Date] BETWEEN @StartDate AND @EndDate), 0)

			SET @TreadmillHours = COALESCE((SELECT SUM(Distance) FROM TreadmillRun
								WHERE [Date] BETWEEN @StartDate AND @EndDate), 0)

			SET @LiftHours = COALESCE((SELECT SUM(NumberOfSets) FROM LiftingSession
								WHERE [Date] BETWEEN @StartDate AND @EndDate), 0)

			SET @StairsHours = COALESCE((SELECT SUM(StairQuantity) FROM Stairs
								WHERE [Date] BETWEEN @StartDate AND @EndDate), 0)

		
		SET @RideHours = (@RideHours / 20)
		SET @StationaryRideHours = (@StationaryRideHours / 20)
		SET @RunHours = (@RunHours / 7.6)
		SET @TreadmillHours = (@TreadmillHours / 7.6)
		SET @LiftHours = (@LiftHours / 8)
		SET @StairsHours = (@StairsHours / 2400)

		SELECT ((@RideHours + 
				@StationaryRideHours + 
				@RunHours +
				@TreadmillHours +
				@LiftHours + 
				@StairsHours) /
				@Divisor)
		
END

GO


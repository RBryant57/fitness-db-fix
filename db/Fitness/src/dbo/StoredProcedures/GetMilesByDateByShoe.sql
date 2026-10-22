


-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 9/1/08
-- Description:	This procedure will return the miles
--				for the given period and given Shoe.
-- =============================================
CREATE PROCEDURE [dbo].[GetMilesByDateByShoe] 
		@StartDate				datetime = null,
		@EndDate				datetime = null,
		@ShoeId					int 

AS
BEGIN

	DECLARE @TrainingMiles			int
	DECLARE @RecreationalMiles		int
	DECLARE @StairMiles				int
	DECLARE @TreadmillMiles			int
	DECLARE @Result					int

	SET NOCOUNT ON;

	IF @StartDate IS NOT NULL
		BEGIN
			SET @TrainingMiles = COALESCE((SELECT SUM(Distance) FROM TrainingRun
						WHERE [Date] BETWEEN @StartDate AND @EndDate AND ShoeId = @ShoeId), 0)
						+
						COALESCE((SELECT SUM(Distance) FROM TrainingWalk
						WHERE [Date] BETWEEN @StartDate AND @EndDate AND ShoeId = @ShoeId), 0)

			SET @RecreationalMiles = COALESCE((SELECT SUM(Distance) FROM RecreationalRun
						WHERE [Date] BETWEEN @StartDate AND @EndDate AND ShoeId = @ShoeId), 0)
						+
						COALESCE((SELECT SUM(Distance) FROM RecreationalWalk
						WHERE [Date] BETWEEN @StartDate AND @EndDate AND ShoeId = @ShoeId), 0)
				
			SET @StairMiles = COALESCE((SELECT (SUM(ElevationGain) / 5280) FROM Stairs
						WHERE [Date] BETWEEN @StartDate AND @EndDate AND ShoeId = @ShoeId), 0)
				
			SET @TreadmillMiles = COALESCE((SELECT SUM(Distance) FROM TreadmillRun
						WHERE [Date] BETWEEN @StartDate AND @EndDate AND ShoeId = @ShoeId), 0)

		END

	IF @StartDate IS NULL
		BEGIN
			SET @TrainingMiles = COALESCE((SELECT SUM(Distance) FROM TrainingRun
						WHERE ShoeId = @ShoeId), 0)
						+
						COALESCE((SELECT SUM(Distance) FROM TrainingWalk
						WHERE ShoeId = @ShoeId), 0)

			SET @RecreationalMiles = COALESCE((SELECT SUM(Distance) FROM RecreationalRun
						WHERE ShoeId = @ShoeId), 0)
						+
						COALESCE((SELECT SUM(Distance) FROM RecreationalWalk
						WHERE ShoeId = @ShoeId), 0)
				
			SET @StairMiles = COALESCE((SELECT (SUM(ElevationGain) / 5280) FROM Stairs
						WHERE ShoeId = @ShoeId), 0)
				
			SET @TreadmillMiles = COALESCE((SELECT SUM(Distance) FROM TreadmillRun
						WHERE ShoeId = @ShoeId), 0)	
		END
	
	
SET @Result = @TrainingMiles + @RecreationalMiles + @StairMiles + @TreadmillMiles


SELECT COALESCE(@Result, 0)














GRANT EXECUTE ON [dbo].[GetMilesByDateByShoe] TO [FitnessLogger]

GRANT EXECUTE ON [dbo].[GetMilesByDateByShoe] TO [FitnessViewer]

END

GO


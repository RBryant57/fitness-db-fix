



-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 9/1/08
-- Description:	This procedure will return the miles
--				for the given Shoe and Run type.
-- =============================================
CREATE PROCEDURE [dbo].[GetMilesByShoeByRunType] 
		@ShoeId					int,
		@RunType				int

AS
BEGIN

	DECLARE @TrainingMiles			int
	DECLARE @RecreationalMiles		int
	DECLARE @Result					int

	SET NOCOUNT ON;

	IF @RunType = 1
		BEGIN
			SET @TrainingMiles = COALESCE((SELECT SUM(Distance) FROM TrainingRun
				WHERE ShoeId = @ShoeId), 0)
			
			SET @RecreationalMiles = 0
		END
	IF @RunType = 2
		BEGIN
			SET @TrainingMiles = 0

			SET @RecreationalMiles = COALESCE((SELECT SUM(Distance) FROM RecreationalRun
				WHERE ShoeId = @ShoeId), 0)
		END

SET @Result = @TrainingMiles + @RecreationalMiles

SELECT COALESCE(@Result, 0)

--END


















--GO
GRANT EXECUTE ON [dbo].[GetMilesByBikeByRideType] TO [FitnessLogger]
--GO
GRANT EXECUTE ON [dbo].[GetMilesByBikeByRideType] TO [FitnessViewer]

END

GO


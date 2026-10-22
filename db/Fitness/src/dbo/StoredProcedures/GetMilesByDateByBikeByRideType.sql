-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 7/1/08
-- Description:	This procedure will return the maximum
--				odometer readings for the given period, 
--				Bike and ride type.
-- =============================================
CREATE PROCEDURE [dbo].[GetMilesByDateByBikeByRideType] 
		@StartDate				datetime,
		@EndDate				datetime,
		@BikeId					int,
		@RideType				int

--======================TYPES=========================
--
--	1:	Training
--	2:	Recreational
--	3:	WithTrainer
--	4:	Stationary
--	5:	StationaryGeneric
--
--=====================================================

AS
BEGIN

	DECLARE @TrainingMiles			int
	DECLARE @RecreationalMiles		int
	DECLARE	@TrainerMiles			int
	DECLARE @Result					int

	SET NOCOUNT ON;

	-- Training Ride
	IF @RideType = 1
		BEGIN
			SET @TrainingMiles = COALESCE((SELECT SUM((EndOdometer - StartOdometer)) FROM TrainingRide
				WHERE [Date] BETWEEN @StartDate AND @EndDate AND BikeId = @BikeId), 0)
			
			SET @RecreationalMiles = 0

			SET @TrainerMiles = 0
		END
	-- Recreational Ride
	IF @RideType = 2
		BEGIN
			SET @TrainingMiles = 0

			SET @RecreationalMiles = COALESCE((SELECT SUM((EndOdometer - StartOdometer)) FROM RecreationalRide
				WHERE [Date] BETWEEN @StartDate AND @EndDate AND BikeId = @BikeId), 0)

			SET @TrainerMiles = 0
		END
	-- With Trainer miles
	IF @RideType = 3
		BEGIN
			SET @TrainingMiles = COALESCE((SELECT SUM((EndOdometer - StartOdometer)) FROM TrainingRide
				WHERE [Date] BETWEEN @StartDate AND @EndDate AND BikeId = @BikeId), 0)
			
			SET @RecreationalMiles = 0

			SET @TrainerMiles = COALESCE((SELECT SUM((EndOdometer - StartOdometer)) FROM StationaryRide
				WHERE [Date] BETWEEN @StartDate AND @EndDate AND BikeId = @BikeId), 0)
		END
	-- Bike Stationary miles
	IF @RideType = 4
		BEGIN
			SET @TrainingMiles = 0
			
			SET @RecreationalMiles = 0

			SET @TrainerMiles = COALESCE((SELECT SUM((EndOdometer - StartOdometer)) FROM StationaryRide
				WHERE [Date] BETWEEN @StartDate AND @EndDate AND BikeId = @BikeId), 0)
		END
	-- Generic Stationary miles
	IF @RideType = 5
		BEGIN
			SET @TrainingMiles = 0
			
			SET @RecreationalMiles = 0

			SET @TrainerMiles = COALESCE((SELECT SUM((EndOdometer - StartOdometer)) FROM StationaryRide
				WHERE [Date] BETWEEN @StartDate AND @EndDate AND BikeId IS NULL), 0)
		END

SET @Result = @TrainingMiles + @RecreationalMiles + @TrainerMiles

IF @Result < 0
	BEGIN
		SET @Result = 0
	END

SELECT COALESCE(@Result, 0)

END

GO


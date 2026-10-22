

-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 7/1/08
-- Description:	This procedure will return the maximum
--				odometer readings for the given period
--				and given Bike.
-- =============================================
CREATE PROCEDURE [dbo].[GetMilesByDateByBike] 
		@StartDate				datetime = null,
		@EndDate				datetime = null,
		@BikeId					int, 
		@IncludeTrainer			bit

AS
BEGIN

	DECLARE @Miles					int
	DECLARE @BikeOnlyMiles			int
	DECLARE	@TrainerMiles			int
	DECLARE @Result					int

	SET NOCOUNT ON;

	IF @StartDate IS NOT NULL
		BEGIN
			SET @Miles = COALESCE((SELECT (dbo.OdometerReading(@EndDate, @BikeId) - dbo.OdometerReading(@StartDate, @BikeId))), 0)
			SET @BikeOnlyMiles = (SELECT dbo.ExceptionalMiles(@StartDate, @EndDate, @BikeId))
			SET @TrainerMiles = COALESCE((SELECT SUM(EndOdometer - StartOdometer) FROM StationaryRide WHERE BikeId = @BikeId AND [Date] BETWEEN @StartDate AND @EndDate), 0)
		END
	ELSE
		BEGIN
			SET @Miles = COALESCE((SELECT dbo.OdometerReading(GETDATE(), @BikeId)), 0)
			SET @BikeOnlyMiles = (SELECT dbo.ExceptionalMiles(NULL, NULL, @BikeId))
			SET @TrainerMiles = COALESCE((SELECT SUM(EndOdometer - StartOdometer) FROM StationaryRide WHERE BikeId = @BikeId), 0)
		END

IF @IncludeTrainer = 1
	BEGIN
		SET @Result = @Miles - @BikeOnlyMiles
	END
ELSE
	BEGIN
		SET @Result = @Miles - @BikeOnlyMiles - @TrainerMiles
	END

IF @Result < 0
	BEGIN
		SET @Result = 0
	END

SELECT COALESCE(@Result, 0)

END

GO


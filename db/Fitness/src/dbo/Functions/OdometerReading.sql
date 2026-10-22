
-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 11/28/08
-- Description:	Calculates the odometer reading for
--				the given date and Bike.
-- =============================================
CREATE FUNCTION [dbo].[OdometerReading] 
(
	@Date					datetime, 
	@BikeId					int
)
RETURNS int
AS
BEGIN

	-- Declare the return variable here
	DECLARE @RecreationalReading			int
	DECLARE @TrainingReading				int
	DECLARE @StationaryReading				int
	DECLARE @NonRideReading					int
	DECLARE @BikeOnlyReading				int
	DECLARE @Result							int

	SET @RecreationalReading = COALESCE((SELECT MAX([EndOdometer]) FROM RecreationalRide
								WHERE BikeId = @BikeId AND [Date] <= @Date), 0)

	SET @TrainingReading = COALESCE((SELECT MAX([EndOdometer]) FROM TrainingRide
								WHERE BikeId = @BikeId AND [Date] <= @Date), 0)

	SET @StationaryReading = COALESCE((SELECT MAX([EndOdometer]) FROM StationaryRide
								WHERE BikeId = @BikeId AND [Date] <= @Date), 0)
								
	SET @NonRideReading = COALESCE((SELECT MAX([EndOdometer]) FROM NonRideMiles
								WHERE BikeId = @BikeId AND [Date] <= @Date), 0)
								
	SET @BikeOnlyReading = COALESCE((SELECT MAX([EndOdometer]) FROM BikeOnlyMiles
								WHERE BikeId = @BikeId AND [Date] <= @Date), 0)
								
								
	DECLARE @MaxOdometer TABLE( Mileage int )
	
	INSERT INTO @MaxOdometer (Mileage) SELECT @RecreationalReading
	INSERT INTO @MaxOdometer (Mileage) SELECT @TrainingReading
	INSERT INTO @MaxOdometer (Mileage) SELECT @StationaryReading
	INSERT INTO @MaxOdometer (Mileage) SELECT @NonRideReading
	INSERT INTO @MaxOdometer (Mileage) SELECT @BikeOnlyReading
	

	SET @Result = COALESCE((SELECT MAX(Mileage) FROM @MaxOdometer), 0)
	

RETURN @Result

END

GO


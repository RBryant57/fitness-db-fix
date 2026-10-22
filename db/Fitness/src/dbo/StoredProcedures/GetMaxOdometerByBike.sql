


-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 7/10/06
-- Description:	This procedure will return the maximum
--				odometer reading for the given Bike.
-- =============================================
CREATE PROCEDURE [dbo].[GetMaxOdometerByBike] 
		@BikeId		int 

AS
BEGIN

	DECLARE @TrainingRide			int
	DECLARE @RecreationalRide		int
	DECLARE	@StationaryRide			int
	DECLARE @BikeOnly				int
	DECLARE @NonRide				int
	DECLARE @Result					int

	SET NOCOUNT ON;

    SET @TrainingRide = COALESCE((SELECT SUM(EndOdometer - StartOdometer) FROM TrainingRide
								WHERE BikeId = @BikeId), 0)

	SET @RecreationalRide = COALESCE((SELECT SUM(EndOdometer - StartOdometer) FROM RecreationalRide
								WHERE BikeId = @BikeId), 0)

	SET @StationaryRide = COALESCE((SELECT SUM(EndOdometer - StartOdometer) FROM StationaryRide
								WHERE BikeId = @BikeId), 0)

	SET @BikeOnly = COALESCE((SELECT SUM(EndOdometer - StartOdometer) FROM BikeOnlyMiles
						WHERE BikeId = @BikeId), 0)

	SET @NonRide = COALESCE((SELECT SUM(EndOdometer - StartOdometer) FROM NonRideMiles
						WHERE BikeId = @BikeId), 0)

	SET @Result = @TrainingRide + @RecreationalRide + @StationaryRide + @BikeOnly + @NonRide

SELECT COALESCE(@Result, 0)

END

GO


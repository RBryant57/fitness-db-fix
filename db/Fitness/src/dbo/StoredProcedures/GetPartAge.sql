




-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 9/20/06
-- Description:	Retrieves the age of the Part on the Bike.
-- =============================================
CREATE PROCEDURE [dbo].[GetPartAge]
	 
	@BikeId				int,
	@PartTypeId			int
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @odometerReading		int

		DECLARE @MaxTrainingRide		int
		DECLARE @MaxRecreationalRide	int
		DECLARE @BaseMiles				int
		
			SET @MaxTrainingRide = COALESCE((SELECT MAX(EndOdometer) FROM TrainingRide
								WHERE BikeId = @BikeId), 0)

			SET @MaxRecreationalRide = COALESCE((SELECT MAX(EndOdometer) FROM RecreationalRide
								WHERE BikeId = @BikeId), 0)

			SET @BaseMiles = COALESCE((SELECT BaseMiles FROM Bike
								WHERE Id = @BikeId), 0)

		IF	@MaxTrainingRide > @MaxRecreationalRide
			BEGIN
				SET @odometerReading = @MaxTrainingRide --+ @BaseMiles
			END
		ELSE
				SET @odometerReading = @MaxRecreationalRide --+ @BaseMiles

		
	SELECT Manufacturer.[Name], Part.[Name], BikePart.StartDate, BikePart.OdometerReading AS 'PartOdometer', @OdometerReading AS 'OdometerReading'
	FROM BikePart 
		INNER JOIN Part ON BikePart.PartId = Part.Id 
		INNER JOIN PartType ON Part.PartTypeId = PartType.Id
		INNER JOIN Manufacturer ON Part.ManufacturerId = Manufacturer.Id
	WHERE
		BikePart.BikeId = @BikeId
		AND PartType.Id = @PartTypeId
		AND BikePart.EndDate IS NULL
		AND BikePart.OdometerReading = (SELECT MIN(BikePart.OdometerReading)
	FROM BikePart 
		INNER JOIN Part ON BikePart.PartId = Part.Id 
		INNER JOIN PartType ON Part.PartTypeId = PartType.Id
	WHERE
		BikePart.BikeId = @BikeId
		AND PartType.Id = @PartTypeId
		AND BikePart.EndDate IS NULL)

END

GO


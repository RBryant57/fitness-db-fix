

-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 8/7/06
-- Description:	Retrieves the current Bike part.
-- =============================================
CREATE PROCEDURE [dbo].[GetCurrentBikePart]
	 
	@BikeId				int,
	@PartTypeId			int
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    SELECT BikePart.Id, PartId
	FROM BikePart 
		INNER JOIN Part ON BikePart.PartId = Part.Id 
		INNER JOIN PartType ON Part.PartTypeId = PartType.Id
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


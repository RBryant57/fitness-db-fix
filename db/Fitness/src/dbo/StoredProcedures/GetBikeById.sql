




-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 4/14/06
-- Description:	Retrieves a Bike from the given Id.
-- =============================================
CREATE PROCEDURE [dbo].[GetBikeById]
	 
	@BikeId		int
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    SELECT Bike.Id, Bike.[Name] AS BikeName, [BikeType].[Name] AS TypeName, TypeId, BaseMiles, 
		   COALESCE(Bike.Notes, ''),
		   Manufacturer.Id AS 'ManufacturerId', Manufacturer.Name AS 'ManufacturerName', COALESCE(Manufacturer.Notes, '') AS 'ManufacturerNotes'
	FROM Bike
		INNER JOIN [BikeType] ON Bike.TypeId = dbo.[BikeType].Id
		INNER JOIN Manufacturer ON Bike.ManufacturerId = Manufacturer.Id

	WHERE
		Bike.Id = @BikeId

END

GO


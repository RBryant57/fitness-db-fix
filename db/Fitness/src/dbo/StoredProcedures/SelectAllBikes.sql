



-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 5/12/06
-- Description:	This stored procedure will select
--				all bikes in the Bike table
-- =============================================
CREATE PROCEDURE [dbo].[SelectAllBikes]
	
AS
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	SELECT Bike.Id, Bike.[Name] AS BikeName, [BikeType].[Name] AS TypeName, TypeId, BaseMiles, 
		   COALESCE(Bike.Notes, ''),
		   Manufacturer.Id AS 'ManufacturerId', Manufacturer.Name AS 'ManufacturerName', COALESCE(Manufacturer.Notes, '') AS 'ManufacturerNotes'
	FROM Bike
		INNER JOIN [BikeType] ON Bike.TypeId = dbo.[BikeType].Id
		INNER JOIN Manufacturer ON Bike.ManufacturerId = Manufacturer.Id

END

GO


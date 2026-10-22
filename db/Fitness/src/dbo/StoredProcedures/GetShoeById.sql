

-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 5/24/08
-- Description:	Retrieves a Shoe from the given Id.
-- =============================================
CREATE PROCEDURE [dbo].[GetShoeById]
	 
	@ShoeId		int
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    SELECT Shoe.Id AS ShoeId, Shoe.[Name] AS ShoeName, Shoe.AcquisitionDate AS ShoeAquisitionDate, Shoe.RetireDate AS ShoeRetireDate, COALESCE(Shoe.Notes, '') AS ShoeNotes, 
		   Manufacturer.Id AS ManufacturerId, Manufacturer.[Name] AS ManufacturerName, 
		   COALESCE(Manufacturer.Notes, '') AS ManufacturerNotes, ShoeType.Id AS ShoeTypeId, 
           ShoeType.[Name] AS ShoeTypeName
	FROM Shoe INNER JOIN
		Manufacturer ON Shoe.ManufacturerId = Manufacturer.Id INNER JOIN
        ShoeType ON Shoe.ShoeTypeId = ShoeType.Id
	WHERE
		Shoe.Id = @ShoeId

END

GO


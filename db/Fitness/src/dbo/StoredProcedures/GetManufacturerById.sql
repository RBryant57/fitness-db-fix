


-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 8/8/06
-- Description:	Retrieves a Part manufacturer from the given Id.
-- =============================================
CREATE PROCEDURE [dbo].[GetManufacturerById]
	 
	@ManufacturerId		int
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    SELECT Id, [Name]
		FROM Manufacturer
	WHERE
		Id = @ManufacturerId

END

GO


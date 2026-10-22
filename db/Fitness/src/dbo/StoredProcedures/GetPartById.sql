








-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 8/7/06
-- Description:	Retrieves a Part from the given Id.
-- =============================================
CREATE PROCEDURE [dbo].[GetPartById]
	 
	@PartId		int
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    SELECT Part.Id AS PartId, Part.[Name] AS PartName, COALESCE(Part.Notes, '') AS PartNotes, 
		   Manufacturer.Id AS ManufacturerId, Manufacturer.[Name] AS ManufacturerName, 
		   COALESCE(Manufacturer.Notes, '') AS ManufacturerNotes, PartType.Id AS PartTypeId, 
           PartType.[Name] AS PartTypeName, 
		   BikePart.StartDate, BikePart.EndDate
	FROM Part INNER JOIN
		Manufacturer ON Part.ManufacturerId = Manufacturer.Id INNER JOIN
        PartType ON Part.PartTypeId = PartType.Id LEFT OUTER JOIN
		BikePart ON Part.Id = BikePart.PartId
	WHERE
		Part.Id = @PartId

END

GO


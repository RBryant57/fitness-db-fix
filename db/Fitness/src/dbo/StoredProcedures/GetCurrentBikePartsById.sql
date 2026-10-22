
-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 8/25/06
-- Description:	Retrieves the current set of Bike parts.
--				by Bike Id number.
-- =============================================
CREATE PROCEDURE [dbo].[GetCurrentBikePartsById]
	 
	@BikeId				int = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	IF @BikeId = 0
		BEGIN
		    SELECT Part.Id AS PartId, Part.[Name] AS PartName, COALESCE(Part.Notes, '') AS PartNotes, 
				Manufacturer.Id AS ManufacturerId, Manufacturer.[Name] AS ManufacturerName, COALESCE(Manufacturer.Notes, '') AS ManufacturerNotes, 
				PartType.Id AS PartTypeId, PartType.[Name] AS PartTypeName, COALESCE(PartType.Notes, '') AS PartTypeNotes,
				BikePart.BikeId
			FROM Part INNER JOIN
				Manufacturer ON Part.ManufacturerId = Manufacturer.Id INNER JOIN
				PartType ON Part.PartTypeId = PartType.Id INNER JOIN
				BikePart ON Part.Id = BikePart.PartId
			WHERE
				BikePart.EndDate IS NULL
			ORDER BY BikePart.BikeId, PartType.[Name]
		END
	ELSE
		BEGIN
			SELECT Part.Id AS PartId, Part.[Name] AS PartName, COALESCE(Part.Notes, '') AS PartNotes, 
				Manufacturer.Id AS ManufacturerId, Manufacturer.[Name] AS ManufacturerName, COALESCE(Manufacturer.Notes, '') AS ManufacturerNotes, 
				PartType.Id AS PartTypeId, PartType.[Name] AS PartTypeName, COALESCE(PartType.Notes, '') AS PartTypeNotes,
				BikePart.BikeId
			FROM Part INNER JOIN
				Manufacturer ON Part.ManufacturerId = Manufacturer.Id INNER JOIN
				PartType ON Part.PartTypeId = PartType.Id INNER JOIN
				BikePart ON Part.Id = BikePart.PartId
			WHERE
				BikeId = @BikeId
			AND
				BikePart.EndDate IS NULL
		END
END

GO


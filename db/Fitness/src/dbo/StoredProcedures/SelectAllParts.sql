



-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 8/7/06
-- Description:	This stored procedure will select
--				all Parts in the Part table.
-- =============================================
CREATE PROCEDURE [dbo].[SelectAllParts]
	
AS
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	SELECT Part.Id, Part.[Name] AS [Name], COALESCE(Part.Notes, '') AS Notes,
		   Manufacturer.Id AS ManufacturerId, Manufacturer.[Name] AS ManufacturerName,
		   PartType.Id AS PartTypeId, PartType.[Name] AS PartTypeName
	FROM Manufacturer 
		INNER JOIN Part ON Manufacturer.Id = Part.ManufacturerId 
		INNER JOIN PartType ON Part.PartTypeId = PartType.Id
	ORDER BY
		Manufacturer.[Name], PartType.[Name]

END

GO


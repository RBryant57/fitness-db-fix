






-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 10/11/06
-- Description:	This stored procedure will select
--				a subset of Parts in the Part table.
-- =============================================
CREATE PROCEDURE [dbo].[SelectAllPartsSubset]
	
	@StartIndex				int,
	@NumberOfRecords		int

AS
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	WITH OrderedParts AS
	(
		SELECT Part.Id, Manufacturer.[Name] AS ManufacturerName, Part.[Name] AS [Name], 
			   PartType.[Name] AS PartTypeName, COALESCE(Part.Notes, '') AS Notes,
			   PartType.Id AS PartTypeId, Manufacturer.Id AS ManufacturerId,
		       ROW_NUMBER()  OVER(ORDER BY Manufacturer.[Name], PartType.[Name])  AS  'RowNumber'
		FROM Manufacturer 
			INNER JOIN Part ON Manufacturer.Id = Part.ManufacturerId 
			INNER JOIN PartType ON Part.PartTypeId = PartType.Id
	)

	SELECT * 
	FROM
		OrderedParts
	WHERE 
		RowNumber BETWEEN @StartIndex AND (@StartIndex + (@NumberOfRecords - 1))
	
	
END

GO


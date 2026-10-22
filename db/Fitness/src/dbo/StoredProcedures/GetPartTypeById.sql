

-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 9/25/06
-- Description:	Retrieves a Part type from the given Id.
-- =============================================
CREATE PROCEDURE [dbo].[GetPartTypeById]
	 
	@PartTypeId			int
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    SELECT Id, [Name]
		FROM PartType
	WHERE
		Id = @PartTypeId

END

GO


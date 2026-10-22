







-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 8/19/06
-- Description:	Retrieves a Part type from the given name.
-- =============================================
CREATE PROCEDURE [dbo].[GetPartTypeByName]
	 
	@PartTypeName		nvarchar(50)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    SELECT Id, [Name]
		FROM PartType
	WHERE
		[Name] = @PartTypeName

END

GO


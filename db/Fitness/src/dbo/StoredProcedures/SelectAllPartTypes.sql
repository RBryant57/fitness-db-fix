




-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 8/7/06
-- Description:	This stored procedure will select
--				all Parts types in the PartType table
-- =============================================
CREATE PROCEDURE [dbo].[SelectAllPartTypes]
	
AS
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	SELECT 
			Id,
			[Name]
	FROM PartType

END

GO


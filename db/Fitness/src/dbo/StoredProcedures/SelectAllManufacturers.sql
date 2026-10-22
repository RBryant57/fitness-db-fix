





-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 8/8/06
-- Description:	This stored procedure will select
--				all Parts manufacturers in the Manufacturer table
-- =============================================
CREATE PROCEDURE [dbo].[SelectAllManufacturers]
	
AS
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	SELECT 
			Id,
			[Name]
	FROM Manufacturer

END

GO


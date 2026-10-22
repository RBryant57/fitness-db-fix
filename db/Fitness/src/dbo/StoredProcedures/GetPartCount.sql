


-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 10/11/06
-- Description:	Retrieves the number of Parts in
--				the Part table.
-- =============================================
CREATE PROCEDURE [dbo].[GetPartCount]
	 
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    SELECT COUNT(Id)
	FROM
		Part

END

GO


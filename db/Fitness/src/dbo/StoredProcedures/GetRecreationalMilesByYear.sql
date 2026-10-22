




-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 10/6/06
-- Description:	This procedure will return the maximum
--				recreational odometer readings for the given year.
-- =============================================
CREATE PROCEDURE [dbo].[GetRecreationalMilesByYear] 
		@Year					int = 0

AS
BEGIN

	SET NOCOUNT ON;

	IF @Year = 0
		SELECT COALESCE(SUM((EndOdometer - StartOdometer)), 0) FROM RecreationalRide
	ELSE
		SELECT COALESCE(SUM((EndOdometer - StartOdometer)), 0) FROM RecreationalRide
			WHERE YEAR([Date]) = @Year

	
END

GO


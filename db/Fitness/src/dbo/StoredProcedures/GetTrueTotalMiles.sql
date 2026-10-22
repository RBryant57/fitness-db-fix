


-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 7/10/06
-- Description:	This procedure will return the full
--				sum of miles in the data store.
-- =============================================
CREATE PROCEDURE [dbo].[GetTrueTotalMiles] 


AS
BEGIN

	DECLARE @TrainingRide			int
	DECLARE @RecreationalRide		int
	DECLARE @BaseMiles				int
	DECLARE @Result					int

	SET NOCOUNT ON;

    SET @TrainingRide = COALESCE((SELECT SUM(EndOdometer - StartOdometer) FROM TrainingRide), 0)

	SET @RecreationalRide = COALESCE((SELECT SUM(EndOdometer - StartOdometer) FROM RecreationalRide), 0)

	SET @BaseMiles = COALESCE((SELECT SUM(BaseMiles) FROM Bike), 0)

	SET @Result = @TrainingRide + @RecreationalRide + @BaseMiles

SELECT @Result

END

GO


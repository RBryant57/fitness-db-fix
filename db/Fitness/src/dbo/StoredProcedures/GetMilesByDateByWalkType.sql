




-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 11/29/10
-- Description:	This procedure will return the distances
--				for the given period and walk type.
-- =============================================
CREATE PROCEDURE [dbo].[GetMilesByDateByWalkType] 
		@StartDate				datetime,
		@EndDate				datetime,
		@RunType				int

AS
BEGIN

	DECLARE @TrainingMiles			int
	DECLARE @RecreationalMiles		int
	DECLARE @Result					int

	SET NOCOUNT ON;

	IF @RunType = 1
		BEGIN
			SET @TrainingMiles = COALESCE((SELECT SUM(Distance) FROM TrainingWalk
				WHERE [Date] BETWEEN @StartDate AND @EndDate), 0)

			SET @RecreationalMiles = 0
		END
	IF @RunType = 2
		BEGIN
			SET @TrainingMiles = 0

			SET @RecreationalMiles = COALESCE((SELECT SUM(Distance) FROM RecreationalWalk
				WHERE [Date] BETWEEN @StartDate AND @EndDate), 0)
		END

SET @Result = @TrainingMiles + @RecreationalMiles

SELECT COALESCE(@Result, 0)

END

GO


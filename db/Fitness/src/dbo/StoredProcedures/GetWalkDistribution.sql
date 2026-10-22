






-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 11/29/10
-- Description:	Retrieves the walk/miles distribution
--				for the given time period.
-- =============================================
CREATE PROCEDURE [dbo].[GetWalkDistribution]

	@StartDate				datetime,
	@EndDate				datetime,
	@Type					int
	 
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	IF @Type = 1
		BEGIN

			SELECT MONTH([Date]) AS 'Month Number', DATENAME(MONTH, [Date]) AS 'Month', COUNT(Id) AS 'Runs' FROM TrainingWalk
				WHERE [Date] BETWEEN @StartDate AND @EndDate
			GROUP BY MONTH([Date]), DATENAME(MONTH, [Date])
			ORDER BY MONTH([Date])

		END

	IF @Type = 2
		BEGIN
			
			SELECT MONTH([Date]) AS 'Month Number', DATENAME(MONTH, [Date]) AS 'Month', SUM(Distance) AS 'Miles' FROM TrainingWalk
				WHERE [Date] BETWEEN @StartDate AND @EndDate
			GROUP BY MONTH([Date]), DATENAME(MONTH, [Date])
			ORDER BY MONTH([Date])

		END

END

GO


-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 11/23/13
-- Description:	This procedure will return weight
--				readings for the given date range.
-- =============================================
CREATE PROCEDURE [dbo].[GetWeightReadingsByDate] 
		@StartDate				datetime = NULL,
		@EndDate				datetime = NULL

AS

IF @StartDate IS NULL
	SET @StartDate = (SELECT MIN([Date]) FROM Weight)

IF @EndDate IS NULL
	SET @EndDate = GETDATE()

BEGIN

	SET NOCOUNT ON;

	SELECT [Date], [Weight], BodyFatPercentage FROM Weight
		WHERE [Date] BETWEEN @StartDate AND @EndDate


END

GO


-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 11/26/08
-- Description:	Calculates the minimum Ride date for
--				the given date period and Bike.
-- =============================================
CREATE FUNCTION [dbo].[MinimumRideDate] 
(
	@StartDate datetime, 
	@EndDate datetime, 
	@BikeId int
)
RETURNS datetime
AS
BEGIN

	-- Declare the return variable here
	DECLARE @RecreationalDate datetime
	DECLARE @TrainingDate datetime
	DECLARE @Result datetime

	SET @RecreationalDate = COALESCE((SELECT MIN([Date]) FROM RecreationalRide
								WHERE BikeId = @BikeId AND [Date] BETWEEN @StartDate AND @EndDate), @StartDate)

	SET @TrainingDate = COALESCE((SELECT MIN([Date]) FROM TrainingRide
								WHERE BikeId = @BikeId AND [Date] BETWEEN @StartDate AND @EndDate), @StartDate)
	
	IF (@RecreationalDate < @TrainingDate)
		BEGIN
			SET @Result = @RecreationalDate
		END
	ELSE
		BEGIN
			SET @Result = @TrainingDate
		END
	

RETURN @Result

END

GO


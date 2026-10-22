-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 11/27/08
-- Description:	Calculates the maximum Ride date for
--				the given date period and Bike.
-- =============================================
CREATE FUNCTION [dbo].[MaximumRideDate] 
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

	SET @RecreationalDate = COALESCE((SELECT MAX([Date]) FROM RecreationalRide
								WHERE BikeId = @BikeId AND [Date] BETWEEN @StartDate AND @EndDate), @StartDate)

	SET @TrainingDate = COALESCE((SELECT MAX([Date]) FROM TrainingRide
								WHERE BikeId = @BikeId AND [Date] BETWEEN @StartDate AND @EndDate), @StartDate)
	
	IF (@RecreationalDate > @TrainingDate)
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


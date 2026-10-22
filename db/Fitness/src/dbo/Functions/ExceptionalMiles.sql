
-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 8/23/08
-- Description:	Calculates whether or not Bike only miles have
--				been accumulated when no other miles have been.
-- =============================================
CREATE FUNCTION [dbo].[ExceptionalMiles] 
(
	@StartDate datetime, 
	@EndDate datetime, 
	@BikeId int
)
RETURNS int
AS
BEGIN
	-- Declare the return variable here
	DECLARE @Result int

	-- For a specific Bike
	IF @BikeId > 0
		BEGIN
			-- For a specific date
			IF (@StartDate IS NOT NULL)
				BEGIN
					SET @Result = COALESCE((SELECT SUM(EndOdometer - StartOdometer) FROM BikeOnlyMiles 
									WHERE BikeId = @BikeId AND ([Date] BETWEEN @StartDate AND @EndDate)), 0)
									
				END
			-- For all dates
			ELSE
				BEGIN
					-- If there are no Bike only miles for the Bike, return with 0.
					SET @Result = COALESCE((SELECT SUM(EndOdometer - StartOdometer) FROM BikeOnlyMiles 
									WHERE BikeId = @BikeId), 0)

				END
		END
	-- For all Bikes
	ELSE
		BEGIN
			-- For a specific date
			IF @StartDate <> null
				BEGIN
					-- If there are no Bike only miles for the period, return with 0.
					SET @Result = COALESCE((SELECT SUM(EndOdometer - StartOdometer) FROM BikeOnlyMiles 
									WHERE [Date] BETWEEN @StartDate AND @EndDate), 0)

				END
			-- For all dates	
			ELSE
				BEGIN
					SET @Result = COALESCE((SELECT SUM(EndOdometer - StartOdometer) FROM BikeOnlyMiles), 0)
				END
		END

	-- Return the result of the function
	RETURN @Result

END

GO


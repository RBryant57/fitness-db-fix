


-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 2/5/08
-- Description:	Inserts a stationary Ride.
-- =============================================
CREATE PROCEDURE [dbo].[InsertStationaryRide]
	
	@Date					datetime,
	@StartOdometer			int,
	@EndOdometer			int,
	@StartTime				datetime,
	@EndTime				datetime,
	@AverageHR				int,
	@MaxHR					int,
	@AverageCadence			int,
	@BikeId					int = null,
	@Notes					ntext = ''

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    INSERT INTO
		StationaryRide
	VALUES(@Date, @StartOdometer, @EndOdometer, @StartTime, @EndTime, 
				DATEPART(hh, @EndTime - @StartTime), DATEPART(mi, @EndTime - @StartTime), DATEPART(ss, @EndTime - @StartTime), 
				@AverageHR, @MaxHR, @AverageCadence, @BikeId, @Notes)

SELECT @@IDENTITY

END

GO


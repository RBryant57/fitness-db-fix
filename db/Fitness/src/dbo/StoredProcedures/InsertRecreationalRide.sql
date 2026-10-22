
-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 7/11/06
-- Description:	Inserts a Recreational Ride.
-- =============================================
CREATE PROCEDURE [dbo].[InsertRecreationalRide]
	
	@Date					datetime,
	@StartOdometer			int,
	@EndOdometer			int,
	@StartTime				datetime,
	@EndTime				datetime,
	@BikeEndTime			datetime,
	@AverageHR				int,
	@MaxHR					int,
	@AverageCadence			int,
	@ElevationGain			int,
	@MaxSpeed				decimal(5,2),
	@Wind					nvarchar(255),
	@Temperature			int,
	@Precipitation			bit,
	@BikeId					int,
	@RouteId				int,
	@Notes					text = ''

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    INSERT INTO
		RecreationalRide
	VALUES(@Date, @StartOdometer, @EndOdometer, @StartTime, @EndTime, 
				DATEPART(hh, @EndTime - @StartTime), DATEPART(mi, @EndTime - @StartTime), DATEPART(ss, @EndTime - @StartTime),
				@BikeEndTime,
				DATEPART(hh, @BikeEndTime - @StartTime), DATEPART(mi, @BikeEndTime - @StartTime), DATEPART(ss, @BikeEndTime - @StartTime),
				@AverageHR, @MaxHR, @AverageCadence, @ElevationGain, @MaxSpeed, @Wind, 
				@Temperature, @Precipitation, @BikeId, @RouteId, @Notes)

	SELECT SCOPE_IDENTITY()

END

GO


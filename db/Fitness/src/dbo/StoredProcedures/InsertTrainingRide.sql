-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 4/14/06
-- Description:	Inserts a training Ride.
-- =============================================
CREATE PROCEDURE [dbo].[InsertTrainingRide]
	
	@Date					datetime,
	@StartOdometer			int,
	@EndOdometer			int,
	@StartTime				datetime,
	@EndTime				datetime,
	@AverageHR				int,
	@MaxHR					int,
	@AverageCadence			int,
	@ElevationGain			int,
	@MaxSpeed				decimal(5,2),
	@WindSpeed				int,
	@WindDirection			nvarchar(3),
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
		TrainingRide
	VALUES(@Date, @StartOdometer, @EndOdometer, @StartTime, @EndTime, 
				DATEPART(hh, @EndTime - @StartTime), DATEPART(mi, @EndTime - @StartTime), DATEPART(ss, @EndTime - @StartTime), 
				@AverageHR, @MaxHR, @AverageCadence, @ElevationGain, @MaxSpeed, @WindSpeed,
				@WindDirection, @Temperature, @Precipitation, @BikeId,
				@RouteId, @Notes)

	SELECT SCOPE_IDENTITY()

END

GO


-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 1/8/08
-- Description:	Inserts a training Run.
-- =============================================
CREATE PROCEDURE [dbo].[InsertTrainingRun]
	
	@Date					datetime,
	@Distance				decimal(18,2),
	@StartTime				datetime,
	@EndTime				datetime,
	@AverageHR				int,
	@MaxHR					int,
	@ElevationGain			int,
	@MaxSpeed				decimal(5,2),
	@WindSpeed				int,
	@WindDirection			nvarchar(3),
	@Temperature			int,
	@Precipitation			bit,
	@ShoeId					int,
	@RouteId				int,
	@Notes					text = ''

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    INSERT INTO
		TrainingRun
	VALUES(@Date, @Distance, @StartTime, @EndTime, 
				DATEPART(hh, @EndTime - @StartTime), DATEPART(mi, @EndTime - @StartTime), DATEPART(ss, @EndTime - @StartTime),
				@AverageHR, @MaxHR, @ElevationGain, @MaxSpeed, @WindSpeed,
				@WindDirection, @Temperature, @Precipitation,
				@ShoeId, @RouteId, @Notes)

	SELECT SCOPE_IDENTITY()

END

GO


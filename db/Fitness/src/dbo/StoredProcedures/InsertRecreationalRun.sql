-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 1/18/08
-- Description:	Inserts a recreational Run.
-- =============================================
CREATE PROCEDURE [dbo].[InsertRecreationalRun]
	
	@Date					datetime,
	@Distance				decimal(18,2),
	@StartTime				datetime,
	@EndTime				datetime,
	@PathEndTime			datetime,
	@AverageHR				int,
	@MaxHR					int,
	@ElevationGain			int,
	@MaxSpeed				decimal(5,2),
	@Wind					nvarchar(255),
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
		RecreationalRun
	VALUES(@Date, @Distance, @StartTime, @EndTime,
				DATEPART(hh, @EndTime - @StartTime), DATEPART(mi, @EndTime - @StartTime), DATEPART(ss, @EndTime - @StartTime),
				@PathEndTime,
				DATEPART(hh, @PathEndTime - @StartTime), DATEPART(mi, @PathEndTime - @StartTime), DATEPART(ss, @PathEndTime - @StartTime),
				@AverageHR, @MaxHR, @ElevationGain, @MaxSpeed, @Wind,
				@Temperature, @Precipitation, @ShoeId, @RouteId, @Notes)

	SELECT SCOPE_IDENTITY()

END

GO


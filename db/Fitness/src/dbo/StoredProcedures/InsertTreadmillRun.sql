


-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 2/13/08
-- Description:	Inserts a treadmill Run.
-- =============================================
CREATE PROCEDURE [dbo].[InsertTreadmillRun]
	
	@Date					datetime,
	@Distance				decimal(18,2),
	@StartTime				datetime,
	@EndTime				datetime,
	@AverageHR				int,
	@MaxHR					int,
	@ElevationGain			int,
	@ShoeId					int,
	@Notes					ntext = ''

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    INSERT INTO
		TreadmillRun
	VALUES(@Date, @Distance, @StartTime, @EndTime, 
				DATEPART(hh, @EndTime - @StartTime), DATEPART(mi, @EndTime - @StartTime), DATEPART(ss, @EndTime - @StartTime),
				@AverageHR, @MaxHR, @ElevationGain, @ShoeId, @Notes)

END

GO


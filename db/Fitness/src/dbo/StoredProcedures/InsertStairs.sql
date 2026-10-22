


-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 3/14/08
-- Description:	Inserts a stair session.
-- =============================================
CREATE PROCEDURE [dbo].[InsertStairs]
	
	@Date					datetime,
	@StairQuantity			int,
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
		Stairs
	VALUES(@Date, @StairQuantity, @StartTime, @EndTime, 
				DATEPART(hh, @EndTime - @StartTime), DATEPART(mi, @EndTime - @StartTime), DATEPART(ss, @EndTime - @StartTime),
				@AverageHR, @MaxHR, @ElevationGain, @ShoeId, @Notes)

END

GO


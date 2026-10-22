




-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 6/30/08
-- Description:	Inserts Bike only miles.
-- =============================================
CREATE PROCEDURE [dbo].[InsertBikeOnlyMiles]
	
	@Date					datetime,
	@StartOdometer			int,
	@EndOdometer			int,
	@BikeId					int,
	@Notes					ntext = ''
	
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	INSERT INTO
		BikeOnlyMiles
	VALUES(@Date, @StartOdometer, @EndOdometer, @BikeId, @Notes)


END

GO


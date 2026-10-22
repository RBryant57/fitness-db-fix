





-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 6/14/10
-- Description:	Inserts Bike miles that are not part of
-- a formal ride.
-- =============================================
CREATE PROCEDURE [dbo].[InsertNonRideMiles]
	
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
		NonRideMiles
	VALUES(@Date, @StartOdometer, @EndOdometer, @BikeId, @Notes)


END

GO


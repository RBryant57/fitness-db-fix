-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 2/15/14
-- Description:	Inserts a recreational Ride GPX file.
-- =============================================
CREATE PROCEDURE [dbo].[InsertRecreationalRideGPX]
	
	@RecreationalRideId					int,
	@GPX								nvarchar(MAX),
	@Notes								text = ''

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    INSERT INTO
		RecreationalRideGPX
	VALUES(@RecreationalRideId,	@GPX, @Notes)

END


GRANT EXECUTE ON [dbo].[InsertRecreationalRideGPX] TO [FitnessLogger] AS [dbo]

GO


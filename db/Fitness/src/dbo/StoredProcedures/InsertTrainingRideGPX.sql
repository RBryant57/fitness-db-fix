-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 2/15/14
-- Description:	Inserts a training Ride GPX file.
-- =============================================
CREATE PROCEDURE [dbo].[InsertTrainingRideGPX]
	
	@TrainingRideId					int,
	@GPX							nvarchar(MAX),
	@Notes							text = ''

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    INSERT INTO
		TrainingRideGPX
	VALUES(@TrainingRideId,	@GPX, @Notes)

END


GRANT EXECUTE ON [dbo].[InsertTrainingRideGPX] TO [FitnessLogger] AS [dbo]

GO


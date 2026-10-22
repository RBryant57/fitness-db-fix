-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 2/15/14
-- Description:	Inserts a training Walk GPX file.
-- =============================================
CREATE PROCEDURE [dbo].[InsertTrainingWalkGPX]
	
	@TrainingWalkId						int,
	@GPX								nvarchar(MAX),
	@Notes								text = ''

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    INSERT INTO
		TrainingWalkGPX
	VALUES(@TrainingWalkId,	@GPX, @Notes)

END


GRANT EXECUTE ON [dbo].[InsertTrainingWalkGPX] TO [FitnessLogger] AS [dbo]

GO


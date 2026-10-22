-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 2/15/14
-- Description:	Inserts a training Run GPX file.
-- =============================================
CREATE PROCEDURE [dbo].[InsertTrainingRunGPX]
	
	@TrainingRunId						int,
	@GPX								nvarchar(MAX),
	@Notes								text = ''

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    INSERT INTO
		TrainingRunGPX
	VALUES(@TrainingRunId,	@GPX, @Notes)

END


GRANT EXECUTE ON [dbo].[InsertTrainingRunGPX] TO [FitnessLogger] AS [dbo]

GO


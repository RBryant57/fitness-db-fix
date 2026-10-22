-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 3/2/2014
-- Description:	This stored procedure will select
--				the GPX for a particular exercise.
-- =============================================
CREATE PROCEDURE [dbo].[SelectGPXByTypeById]

	@Type			int,
	@Id					int
	
AS
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    IF @Type = 1
		SELECT Id, TrainingRideId, GPX
		FROM TrainingRideGPX 
		WHERE TrainingRideId = @Id

	IF @Type = 2
		SELECT Id, TrainingRunId, GPX
		FROM TrainingRunGPX 
		WHERE TrainingRunId = @Id

	IF @Type = 6
		SELECT Id, RecreationalRideId, GPX
		FROM RecreationalRideGPX 
		WHERE RecreationalRideId = @Id

	IF @Type = 7
		SELECT Id, RecreationalRunId, GPX
		FROM RecreationalRunGPX 
		WHERE RecreationalRunId = @Id

	IF @Type = 8
		SELECT Id, TrainingWalkId, GPX
		FROM TrainingWalkGPX 
		WHERE TrainingWalkId = @Id

    IF @Type = 9
		SELECT Id, RecreationalWalkId, GPX
		FROM RecreationalWalkGPX 
		WHERE RecreationalWalkId = @Id

END

GO


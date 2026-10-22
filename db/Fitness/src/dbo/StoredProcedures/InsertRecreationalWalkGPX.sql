-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 2/15/14
-- Description:	Inserts a recreational Walk GPX file.
-- =============================================
CREATE PROCEDURE [dbo].[InsertRecreationalWalkGPX]
	
	@RecreationalWalkId					int,
	@GPX								nvarchar(MAX),
	@Notes								text = ''

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    INSERT INTO
		RecreationalWalkGPX
	VALUES(@RecreationalWalkId,	@GPX, @Notes)

END


GRANT EXECUTE ON [dbo].[InsertRecreationalWalkGPX] TO [FitnessLogger] AS [dbo]

GO


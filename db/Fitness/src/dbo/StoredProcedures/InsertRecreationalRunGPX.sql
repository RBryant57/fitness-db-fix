-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 2/15/14
-- Description:	Inserts a recreational Run GPX file.
-- =============================================
CREATE PROCEDURE [dbo].[InsertRecreationalRunGPX]
	
	@RecreationalRunId					int,
	@GPX								nvarchar(MAX),
	@Notes								text = ''

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    INSERT INTO
		RecreationalRunGPX
	VALUES(@RecreationalRunId,	@GPX, @Notes)

END


GRANT EXECUTE ON [dbo].[InsertRecreationalRunGPX] TO [FitnessLogger] AS [dbo]

GO


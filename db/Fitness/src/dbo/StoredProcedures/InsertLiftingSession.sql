





-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 1/31/08
-- Description:	Inserts a Lifting session.
-- =============================================
CREATE PROCEDURE [dbo].[InsertLiftingSession]
	
	@Date						datetime,
	@CircuitId					int,
	@NumberOfSets				int,
	@Notes						ntext = ''

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;



    INSERT INTO
		LiftingSession
			([Date], CircuitId, NumberOfSets, Notes)
	VALUES(@Date, @CircuitId, @NumberOfSets, @Notes)

SELECT @@IDENTITY

END

GO


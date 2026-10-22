


-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 1/29/08
-- Description:	Retrieves a CircuitComponent from the given Id.
-- =============================================
CREATE PROCEDURE [dbo].[GetCircuitComponentById]
	 
	@CircuitComponentId				int
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    SELECT Id, ExerciseName, Notes
		FROM CircuitComponent
	WHERE
		Id = @CircuitComponentId

END

GO


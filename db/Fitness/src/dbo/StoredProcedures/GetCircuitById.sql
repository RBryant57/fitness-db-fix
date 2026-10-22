


-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 1/29/08
-- Description:	Retrieves a Circuit from the given Id.
-- =============================================
CREATE PROCEDURE [dbo].[GetCircuitById]
	 
	@CircuitId					int
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    SELECT Id, [Name], Notes
		FROM Circuit
	WHERE
		Id = @CircuitId

END

GO


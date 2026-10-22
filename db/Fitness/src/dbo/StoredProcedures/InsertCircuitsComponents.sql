





-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 1/29/08
-- Description:	Inserts a Circuit/Component relationship.
-- =============================================
CREATE PROCEDURE [dbo].[InsertCircuitsComponents]
	
	@CircuitId							int,
	@CircuitComponentId					int

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;



    INSERT INTO
		CircuitsComponents
			(CircuitId, CircuitComponentId)
	VALUES(@CircuitId, @CircuitComponentId)

END

GO


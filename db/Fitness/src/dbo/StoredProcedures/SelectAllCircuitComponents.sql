




-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 1/30/08
-- Description:	This stored procedure will select
--				all CircuitComponents in the database.
-- =============================================
CREATE PROCEDURE [dbo].[SelectAllCircuitComponents]
	
AS
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	SELECT 
			Id,
			ExerciseName,
			COALESCE(Notes, '')
	FROM CircuitComponent

END

GO


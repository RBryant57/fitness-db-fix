





-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 1/29/08
-- Description:	Inserts a CircuitComponent.
-- =============================================
CREATE PROCEDURE [dbo].[InsertCircuitComponent]
	
	@ExerciseName						nvarchar(100),
	@Notes								ntext = ''

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;



    INSERT INTO
		CircuitComponent
			(ExerciseName, Notes)
	VALUES(@ExerciseName, @Notes)

SELECT @@IDENTITY

END

GO


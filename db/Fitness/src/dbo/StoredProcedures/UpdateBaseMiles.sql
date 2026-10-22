





-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 10/20/06
-- Description:	Updates the base miles of a Bike.
-- =============================================
CREATE PROCEDURE [dbo].[UpdateBaseMiles]
	
	@BikeId					int,
	@Miles					int
	
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @currentBaseMiles		int
	
	SET @currentBaseMiles = (SELECT BaseMiles FROM Bike
							WHERE Id = @BikeId)

	
	UPDATE Bike
		SET 
			BaseMiles = @CurrentBaseMiles + @Miles
		WHERE
			Id = @BikeId

END

GO


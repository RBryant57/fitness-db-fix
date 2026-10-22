




-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 8/14/06
-- Description:	Adds an end date to a Bike part.
-- =============================================
CREATE PROCEDURE [dbo].[RemoveBikePart]
	
	@Id						int,
	@EndDate				datetime

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;



    UPDATE
		BikePart
	SET
		EndDate = @EndDate
	WHERE
		Id = @Id

END

GO








-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 8/14/06
-- Description:	Inserts a Bike part.
-- =============================================
CREATE PROCEDURE [dbo].[InsertBikePart]
	
	@BikeId					int,
	@PartId					int,
	@StartDate				datetime,
	@OdometerReading		int

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;



    INSERT INTO
		BikePart
			(BikeId, PartId, StartDate, OdometerReading)
	VALUES(@BikeId, @PartId, @StartDate, @OdometerReading)

SELECT @@Identity

END

GO


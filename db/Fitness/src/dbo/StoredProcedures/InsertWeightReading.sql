





-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 2/4/08
-- Description:	Inserts a weight reading.
-- =============================================
CREATE PROCEDURE [dbo].[InsertWeightReading]
	
	@Date							datetime,
	@Weight							decimal(4,1),
	@BodyFatPercentage				decimal(4,2),
	@Notes							ntext = ''

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;



    INSERT INTO
		Weight
			([Date], Weight, BodyFatPercentage, Notes)
	VALUES(@Date, @Weight, @BodyFatPercentage, @Notes)

SELECT @@IDENTITY

END

GO


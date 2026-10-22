-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 4/20/13
-- Description:	Inserts a Bike.
-- =============================================
CREATE PROCEDURE [dbo].[InsertBike]
	
	@Name					nvarchar(50),
	@ManufacturerId			int,
	@TypeId					int,
	@AcquisitionDate		datetime,
	@BaseMiles				int = 0,
	@Notes					ntext = ''

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;



    INSERT INTO
		Bike
			(Name, ManufacturerId, TypeId, AcquisitionDate, BaseMiles, Notes)
	VALUES(@Name, @ManufacturerId, @TypeId, @AcquisitionDate, @BaseMiles, @Notes)

SELECT @@Identity

END

GO


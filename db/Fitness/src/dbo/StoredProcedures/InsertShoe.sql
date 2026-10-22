



-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 5/24/08
-- Description:	Inserts a Shoe.
-- =============================================
CREATE PROCEDURE [dbo].[InsertShoe]
	
	@Name					nvarchar(50),
	@ManufacturerId			int,
	@ShoeTypeId				int,
	@AcquisitionDate		datetime,
	@RetireDate				datetime = NULL,
	@Notes					ntext = ''
	
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    INSERT INTO
		Shoe
	VALUES(@Name, @ManufacturerId, @ShoeTypeId, @AcquisitionDate, @RetireDate, @Notes)

SELECT @@Identity

END

GO


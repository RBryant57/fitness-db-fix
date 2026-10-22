


-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 8/8/06
-- Description:	Inserts a Part manufacturer.
-- =============================================
CREATE PROCEDURE [dbo].[InsertManufacturer]
	
	@Name					nvarchar(50),
	@Notes					text = ''
	
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    INSERT INTO
		Manufacturer
	VALUES(@Name, @Notes)

SELECT @@Identity

END

GO


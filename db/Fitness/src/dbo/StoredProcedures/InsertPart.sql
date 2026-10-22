



-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 8/9/06
-- Description:	Inserts a Part.
-- =============================================
CREATE PROCEDURE [dbo].[InsertPart]
	
	@ManufacturerId			int,
	@PartTypeId				int,
	@Name					nvarchar(50),
	@Notes					text = ''
	
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    INSERT INTO
		Part
	VALUES(@ManufacturerId, @PartTypeId, @Name, @Notes)

SELECT @@Identity

END

GO


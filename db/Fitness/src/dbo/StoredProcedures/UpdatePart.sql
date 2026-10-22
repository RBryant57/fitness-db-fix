

-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 10/4/06
-- Description:	Updates a Part.
-- =============================================
CREATE PROCEDURE [dbo].[UpdatePart]
	
	@Id						int,
	@ManufacturerId			int,
	@PartTypeId				int,
	@Name					nvarchar(50),
	@Notes					nvarchar(255) = ''

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    UPDATE
		Part
	SET
		ManufacturerId = @ManufacturerId,
		PartTypeId = @PartTypeId,
		[Name] = @Name,
		Notes = @Notes
	WHERE
		Id = @Id

END

GO



-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 12/8/06
-- Description:	Updates a Route picture.
-- =============================================
CREATE PROCEDURE [dbo].[UpdateRoutePicture]
	
	@Id						int,
	@ImageFileName			nvarchar(100),
	@ImageDescription		text = ''

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    UPDATE RoutePicture
		SET
			ImageFileName = @ImageFileName,
			ImageDescription = @ImageDescription
		WHERE
			Id = @Id

END

GO


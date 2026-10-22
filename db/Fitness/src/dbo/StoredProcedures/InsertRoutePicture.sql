







-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 11/24/06
-- Description:	Inserts a Route picture.
-- =============================================
CREATE PROCEDURE [dbo].[InsertRoutePicture]
	
	@RouteId				int,
	@ImageFileName			nvarchar(100),
	@ImageDescription		text = ''

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    INSERT INTO
		RoutePicture
	VALUES(@RouteId, @ImageFileName, @ImageDescription)

SELECT @@Identity

END

GO


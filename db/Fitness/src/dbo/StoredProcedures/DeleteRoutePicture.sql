
-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 12/8/06
-- Description:	Removes a Route picture.
-- =============================================
CREATE PROCEDURE [dbo].[DeleteRoutePicture]
	
	@Id						int

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    DELETE FROM 
		RoutePicture
	WHERE
		Id = @Id

END

GO






-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 10/6/06
-- Description:	Inserts missed miles.
-- =============================================
CREATE PROCEDURE [dbo].[InsertMissedMiles]
	
	@Date					datetime,
	@Miles					int,
	@Type					int,
	@Notes					ntext = ''
	
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	INSERT INTO
		MissedMiles
	VALUES(@Date, @Miles, @Type, @Notes)


END

GO


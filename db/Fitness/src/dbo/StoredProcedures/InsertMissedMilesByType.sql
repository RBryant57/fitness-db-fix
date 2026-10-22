



-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 1/15/08
-- Description:	Inserts missed miles by type.
-- =============================================
CREATE PROCEDURE [dbo].[InsertMissedMilesByType]
	
	@Date					datetime,
	@Miles					decimal(18, 2),
	@TypeName				varchar(50)
	
AS
BEGIN

	DECLARE @Type			int

	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SET @Type = (SELECT Id FROM ExerciseType WHERE [Name] = @TypeName)

	INSERT INTO
		MissedMiles
	VALUES(@Date, @Miles, @Type)


END

GO







-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 4/14/06
-- Description:	Inserts a Route.
-- =============================================
CREATE PROCEDURE [dbo].[InsertRoute]
	
	@Name					nvarchar(50),
	@City					nvarchar(50),
	@State					char(2),
	@TypeId					int,
	@Rating					int,
	@Notes					text

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

DECLARE @RouteTypeId				int

SET @RouteTypeId = (SELECT Id FROM RouteType WHERE EnumId = @TypeId)

    INSERT INTO
		[Route]
	VALUES(@Name, @City, @State, 
		@RouteTypeId, @Rating, @Notes)

SELECT @@Identity

END

GO


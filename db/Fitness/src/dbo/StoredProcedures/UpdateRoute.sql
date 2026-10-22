







-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 7/28/06
-- Description:	Updates a Route
-- =============================================
CREATE PROCEDURE [dbo].[UpdateRoute]
	
	@Id						int,
	@Name					nvarchar(50),
	@City					nvarchar(50),
	@State					char(2),
	@RouteType				int,
	@Rating					int,
	@Notes					text

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    UPDATE
		[Route]
	SET
		[Name] = @Name,
		City = @City,
		State = @State,
		TypeId = @RouteType,
		Rating = @Rating,
		Notes = @Notes
	WHERE
		Id = @Id

END

GO


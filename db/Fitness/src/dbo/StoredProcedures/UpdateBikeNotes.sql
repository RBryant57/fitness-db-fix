


-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 10/4/06
-- Description:	Updates Bike notes.
-- =============================================
CREATE PROCEDURE [dbo].[UpdateBikeNotes]
	
	@Id						int,
	@Notes					nvarchar(255) = ''

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    UPDATE
		Bike
	SET
		Notes = @Notes
	WHERE
		Id = @Id

END

GO








-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 1/29/08
-- Description:	Inserts a Circuit.
-- =============================================
CREATE PROCEDURE [dbo].[InsertCircuit]
	
	@Name						nvarchar(100),
	@Notes						ntext = ''

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;



    INSERT INTO
		Circuit
			([Name], Notes)
	VALUES(@Name, @Notes)

SELECT @@IDENTITY

END

GO


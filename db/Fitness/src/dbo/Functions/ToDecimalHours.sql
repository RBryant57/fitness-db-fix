



-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date, ,>
-- Description:	<Description, ,>
-- =============================================
CREATE FUNCTION [dbo].[ToDecimalHours] 
(
	-- Add the parameters for the function here
	@Hours int,
	@Minutes int
)
RETURNS decimal
AS
BEGIN
	Return @Hours+(CAST(@Minutes AS decimal)/60.0)
END

GO





-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 10/12/06
-- Description:	This stored procedure will select
--				a subset of Parts in the Part table.
-- =============================================
CREATE PROCEDURE [dbo].[GetMaintenanceSubset]
	
	@BikeId					int,
	@StartIndex				int,
	@NumberOfRecords		int

AS
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	WITH MaintenanceParts AS
	(
		SELECT [Bike], [Operation Date], Manufacturer, Part, 
			[Part Type], [Action Taken], Odometer, Notes,
			ROW_NUMBER()  OVER(ORDER BY Odometer)  AS  'RowNumber'
		FROM 
			MaintenanceLog
		WHERE
			[Bike] = @BikeId
	)

	SELECT * 
	FROM
		MaintenanceParts
	WHERE 
		RowNumber BETWEEN @StartIndex AND (@StartIndex + (@NumberOfRecords - 1))
	
	
END

GO


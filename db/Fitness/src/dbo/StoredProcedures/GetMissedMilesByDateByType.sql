





-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 7/1/08
-- Description:	This procedure will return the missed
--				miles for the given type and period.
-- =============================================
CREATE PROCEDURE [dbo].[GetMissedMilesByDateByType] 
		@StartDate				datetime = null,
		@EndDate				datetime = null,
		@TypeName				nvarchar(50)

AS
BEGIN

	SET NOCOUNT ON;
	IF @StartDate IS NOT NULL
		BEGIN

			SELECT COALESCE(SUM(Miles), 0) FROM MissedMiles
				WHERE [Date] BETWEEN @StartDate AND @EndDate AND [ExerciseTypeId] = 
				(SELECT Id FROM ExerciseType WHERE [Name] = @TypeName)

		END
	ELSE
		BEGIN

			SELECT COALESCE(SUM(Miles), 0) FROM MissedMiles
				WHERE [ExerciseTypeId] = (SELECT Id FROM ExerciseType WHERE [Name] = @TypeName)

		END

END

GO


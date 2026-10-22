





-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 2/23/08
-- Description:	This procedure will return the exercise
--				hours for the given date and given
--				divisors.
-- =============================================
CREATE PROCEDURE [dbo].[GetExerciseHoursByDate] 
		@StartDate				datetime,
		@EndDate				datetime,
		@RideDivisor			decimal(18,2),
		@RunDivisor				decimal(18,2),
		@LiftDivisor			int

AS

	DECLARE @Result					decimal(18,2)
	DECLARE @RidingHours			decimal(18,2)
	DECLARE @RunningHours			decimal(18,2)
	DECLARE @LiftingHours			decimal(18,2)

	SET NOCOUNT ON;
BEGIN


	SET @RidingHours = COALESCE((SELECT (SUM(EndOdometer - StartOdometer) / @RideDivisor) FROM TrainingRide
								WHERE [Date] BETWEEN @StartDate AND @EndDate), 0)

	SET @RunningHours = COALESCE((SELECT (SUM(Distance) / @RunDivisor) FROM TrainingRun 
								WHERE [Date] BETWEEN @StartDate AND @EndDate), 0)

	SET @LiftingHours = COALESCE((SELECT (SUM(NumberOfSets) / @LiftDivisor) FROM LiftingSession		
								WHERE [Date] BETWEEN @StartDate AND @EndDate), 0)

	
END

SET @Result = @RidingHours + @RunningHours + @LiftingHours

SELECT COALESCE(@Result, 0)

GO


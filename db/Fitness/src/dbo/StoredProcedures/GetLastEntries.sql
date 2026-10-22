-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 03/25/19
-- Description:	Shows the last entries for all the
--              activity tables.
-- =============================================
CREATE PROCEDURE [dbo].[GetLastEntries] 

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SELECT *
	FROM(
		SELECT TOP 1 [Date] AS ActivityDate, 'Last Lifting Session' AS Activity FROM LiftingSession
		ORDER BY [Date] DESC
		
		UNION ALL

		SELECT TOP 1 [StartTime], 'Last Recreational Ride' FROM RecreationalRide 
		ORDER BY [StartTime] DESC
		
		UNION ALL

		SELECT TOP 1 [StartTime], 'Last Recreational Run' FROM RecreationalRun
		ORDER BY [StartTime] DESC
		
		UNION ALL

		SELECT TOP 1 [StartTime], 'Last Recreational Walk' FROM RecreationalWalk 
		ORDER BY [StartTime] DESC
		
		UNION ALL

		SELECT TOP 1 [StartTime], 'Last Stationary Ride' FROM StationaryRide 
		ORDER BY [StartTime] DESC
		
		UNION ALL

		SELECT TOP 1 [StartTime], 'Last Training Ride' FROM TrainingRide 
		ORDER BY [StartTime] DESC
		
		UNION ALL

		SELECT TOP 1 [StartTime], 'Last Training Run' FROM TrainingRun 
		ORDER BY [StartTime] DESC
		
		UNION ALL

		SELECT TOP 1 [StartTime], 'Last Training Walk' FROM TrainingWalk
		ORDER BY [StartTime] DESC
		
		UNION ALL

		SELECT TOP 1 [StartTime], 'Last Treadmill Run' FROM TreadmillRun
		ORDER BY [StartTime] DESC
		
		UNION ALL

		SELECT TOP 1 [Date], 'Last Weight Reading' FROM Weight
		ORDER BY [Date] DESC
	) t
	ORDER BY ActivityDate DESC
	
END

GO


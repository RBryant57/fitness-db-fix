-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 7/1/08
-- Description:	This procedure will return the mileage
--				for the given period and type.
-- =============================================
CREATE PROCEDURE [dbo].[GetMilesByDateByType] 
		@StartDate				datetime = null,
		@EndDate				datetime = null,
		@Type					int 

--======================TYPES=========================
--
--	1:	Ride not counting trainer miles
--	2:	Run
--	3:	Walk
--	4:	Stationary Ride
--	5:	Treadmill Run
--	6:	Recreational Ride
--	7:	Recreational Run
--	8:	Training Walk
--	9:	Recreational Walk
--	10:	Stairs
--	11:	Ride counting trainer miles
--	12: Stationary Ride not counting trainer miles
--
--=====================================================

AS
BEGIN

	DECLARE @TrainingMiles			int
	DECLARE @RecreationalMiles		int
	DECLARE @Result					int

	SET NOCOUNT ON;

	-- Ride not counting trainer miles
	IF @Type = 1

		BEGIN

			DECLARE @Miles int
			DECLARE @BikeId int
			
			SET @Miles = 0
			
			DECLARE Bike_Cursor CURSOR FOR
				SELECT Id FROM Bike

			OPEN Bike_Cursor

				FETCH NEXT FROM Bike_Cursor
					INTO @BikeId

			WHILE @@FETCH_STATUS = 0
				BEGIN
		
					IF @StartDate IS NOT NULL
						BEGIN
							SET @Miles = @Miles + COALESCE((SELECT (dbo.OdometerReading(@EndDate, @BikeId) - dbo.OdometerReading(@StartDate, @BikeId))), 0)
							SET @Miles = @Miles - COALESCE((SELECT SUM(EndOdometer - StartOdometer) FROM StationaryRide WHERE BikeId = @BikeId AND Date BETWEEN @StartDate AND @EndDate), 0 )
							SET @Miles = @Miles - COALESCE((SELECT dbo.ExceptionalMiles(@StartDate, @EndDate, @BikeId)), 0)
						END
					ELSE
						BEGIN
							SET @Miles = @Miles + COALESCE((SELECT dbo.OdometerReading(GETDATE(), @BikeId)), 0)
							SET @Miles = @Miles - COALESCE((SELECT SUM(EndOdometer - StartOdometer) FROM StationaryRide WHERE BikeId = @BikeId), 0 )
							SET @Miles = @Miles - COALESCE((SELECT dbo.ExceptionalMiles(NULL, NULL, @BikeId)), 0)
						END

					FETCH NEXT FROM Bike_Cursor
						INTO @BikeId
				END	

			CLOSE Bike_Cursor
			DEALLOCATE Bike_Cursor

			SET @TrainingMiles = @Miles

			SET @RecreationalMiles = 0
			
		END

	-- Ride counting trainer miles
	IF @Type = 11

		BEGIN
			
			SET @Miles = 0
			
			DECLARE Bike_Cursor CURSOR FOR
				SELECT Id FROM Bike

			OPEN Bike_Cursor

				FETCH NEXT FROM Bike_Cursor
					INTO @BikeId

			WHILE @@FETCH_STATUS = 0
				BEGIN
		
					IF @StartDate IS NOT NULL
						BEGIN
							SET @Miles = @Miles + COALESCE((SELECT (dbo.OdometerReading(@EndDate, @BikeId) - dbo.OdometerReading(@StartDate, @BikeId))), 0)
							SET @Miles = @Miles - COALESCE((SELECT dbo.ExceptionalMiles(@StartDate, @EndDate, @BikeId)), 0)
						END
					ELSE
						BEGIN
							SET @Miles = @Miles + COALESCE((SELECT dbo.OdometerReading(GETDATE(), @BikeId)), 0)
							SET @Miles = @Miles - COALESCE((SELECT dbo.ExceptionalMiles(NULL, NULL, @BikeId)), 0)
						END

					FETCH NEXT FROM Bike_Cursor
						INTO @BikeId
				END	

			CLOSE Bike_Cursor
			DEALLOCATE Bike_Cursor

			SET @TrainingMiles = @Miles

			SET @RecreationalMiles = 0
			
		END

	-- Run
	IF @Type = 2

		BEGIN
			IF @StartDate IS NOT NULL
				BEGIN
					SET @TrainingMiles = COALESCE((SELECT SUM(Distance) FROM TrainingRun
						WHERE [Date] BETWEEN @StartDate AND @EndDate), 0)

					SET @RecreationalMiles = COALESCE((SELECT SUM(Distance) FROM RecreationalRun
						WHERE [Date] BETWEEN @StartDate AND @EndDate), 0)
				END
			ELSE
				BEGIN
					SET @TrainingMiles = COALESCE((SELECT SUM(Distance) FROM TrainingRun), 0)

					SET @RecreationalMiles = COALESCE((SELECT SUM(Distance) FROM RecreationalRun), 0)
				END
		END
		
	-- Walk
	IF @Type = 3

		BEGIN
			IF @StartDate IS NOT NULL
				BEGIN
					SET @TrainingMiles = COALESCE((SELECT SUM(Distance) FROM TrainingWalk
						WHERE [Date] BETWEEN @StartDate AND @EndDate), 0)

					SET @RecreationalMiles = COALESCE((SELECT SUM(Distance) FROM RecreationalWalk
						WHERE [Date] BETWEEN @StartDate AND @EndDate), 0)
				END
			ELSE
				BEGIN
					SET @TrainingMiles = COALESCE((SELECT SUM(Distance) FROM TrainingWalk), 0)

					SET @RecreationalMiles = COALESCE((SELECT SUM(Distance) FROM RecreationalWalk), 0)
				END
		END

	-- Stationary Ride
	IF @Type = 4

		BEGIN
			IF @StartDate IS NOT NULL
				BEGIN
					SET @TrainingMiles = COALESCE((SELECT SUM(EndOdometer - StartOdometer) FROM StationaryRide
						WHERE [Date] BETWEEN @StartDate AND @EndDate), 0)

					SET @RecreationalMiles =  0
				END
			ELSE
				BEGIN
					SET @TrainingMiles = COALESCE((SELECT SUM(EndOdometer - StartOdometer) FROM StationaryRide), 0)

					SET @RecreationalMiles = 0
				END
		END

	-- Stationary Ride not counting trainer miles
	IF @Type = 12

		BEGIN
			IF @StartDate IS NOT NULL
				BEGIN
					SET @TrainingMiles = COALESCE((SELECT SUM(EndOdometer - StartOdometer) FROM StationaryRide
						WHERE [Date] BETWEEN @StartDate AND @EndDate AND BikeId IS NULL), 0)

					SET @RecreationalMiles =  0
				END
			ELSE
				BEGIN
					SET @TrainingMiles = COALESCE((SELECT SUM(EndOdometer - StartOdometer) FROM StationaryRide WHERE BikeId IS NULL), 0)

					SET @RecreationalMiles = 0
				END
		END

	-- Treadmill Run
	IF @Type = 5

		BEGIN
			SET @TrainingMiles = COALESCE((SELECT SUM(Distance) FROM TreadmillRun
				WHERE [Date] BETWEEN @StartDate AND @EndDate), 0)

			SET @RecreationalMiles = COALESCE((SELECT SUM(Distance) FROM TreadmillRun
				WHERE [Date] BETWEEN @StartDate AND @EndDate), 0)
		END


SET @Result = @TrainingMiles + @RecreationalMiles

SELECT COALESCE(@Result, 0)

END

GO


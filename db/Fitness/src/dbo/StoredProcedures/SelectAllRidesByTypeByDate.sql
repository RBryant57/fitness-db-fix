


-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 4/11/2008
-- Description:	This stored procedure will select
--				all Rides of a particular type by date.
-- =============================================
CREATE PROCEDURE [dbo].[SelectAllRidesByTypeByDate]

	@RideType			int,
	@StartDate			datetime,
	@EndDate			datetime
	
AS
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    IF @RideType = 1
		SELECT TrainingRide.Id, TrainingRide.Date, TrainingRide.StartOdometer, TrainingRide.EndOdometer, TrainingRide.StartTime, TrainingRide.EndTime, 
                      TrainingRide.RideTimeHours, TrainingRide.RideTimeMinutes, TrainingRide.RideTimeSeconds, TrainingRide.AverageHR, TrainingRide.MaxHR, 
                      TrainingRide.AverageCadence, TrainingRide.ElevationGain, TrainingRide.WindSpeed, TrainingRide.WindDirection, TrainingRide.Temperature, 
                      TrainingRide.Precipitation, TrainingRide.BikeId, TrainingRide.RouteId, TrainingRide.Notes, Bike.Id AS 'BikeId', Bike.Name, 
                      Bike.ManufacturerId, Bike.TypeId, Bike.AcquisitionDate, Bike.BaseMiles, Bike.Notes AS 'BikeNotes', BikeType.Id AS 'BikeTypeId', BikeType.EnumId, 
                      BikeType.Name AS 'BikeTypeName', Route.Id AS 'RouteId', Route.Name AS 'RouteName', Route.City, Route.State, Route.TypeId AS 'RouteTypeId', Route.Rating, 
                      Route.Notes AS 'RouteNotes', RouteType.Id AS 'RouteTypeId', RouteType.EnumId AS 'RouteTypeEnumId', RouteType.Name AS 'RouteTypeName', Manufacturer.Id AS 'ManufacturerId', 
                      Manufacturer.Name AS 'ManufacturerName', Manufacturer.Notes AS 'ManufacturerNotes'
		FROM TrainingRide INNER JOIN
                      Bike ON TrainingRide.BikeId = Bike.Id INNER JOIN
                      BikeType ON Bike.TypeId = BikeType.Id INNER JOIN
                      Route ON TrainingRide.RouteId = Route.Id INNER JOIN
                      RouteType ON Route.TypeId = RouteType.Id INNER JOIN
                      Manufacturer ON Bike.ManufacturerId = Manufacturer.Id
		WHERE [Date] BETWEEN @StartDate AND @EndDate

	IF @RideType = 2
		SELECT RecreationalRide.Id, RecreationalRide.Date, RecreationalRide.StartOdometer, RecreationalRide.EndOdometer, RecreationalRide.StartTime, RecreationalRide.EndTime, 
                      RecreationalRide.RideTimeHours, RecreationalRide.RideTimeMinutes, RecreationalRide.RideTimeSeconds, RecreationalRide.BikeTimeHours, RecreationalRide.BikeTimeMinutes, 
					  RecreationalRide.BikeTimeSeconds, RecreationalRide.AverageHR, RecreationalRide.MaxHR, RecreationalRide.AverageCadence, RecreationalRide.ElevationGain, RecreationalRide.MaxSpeed, 
                      RecreationalRide.Wind, RecreationalRide.Temperature, RecreationalRide.Precipitation, RecreationalRide.BikeId, RecreationalRide.RouteId, RecreationalRide.Notes, Bike.Id AS 'BikeId', Bike.Name, 
                      Bike.ManufacturerId, Bike.TypeId, Bike.AcquisitionDate, Bike.BaseMiles, Bike.Notes AS 'BikeNotes', BikeType.Id AS 'BikeTypeId', BikeType.EnumId, 
                      BikeType.Name AS 'BikeTypeName', Route.Id AS 'RouteId', Route.Name AS 'RouteName', Route.City, Route.State, Route.TypeId AS 'RouteTypeId', Route.Rating, 
                      Route.Notes AS 'RouteNotes', RouteType.Id AS 'RouteTypeId', RouteType.EnumId AS 'RouteTypeEnumId', RouteType.Name AS 'RouteTypeName', Manufacturer.Id AS 'ManufacturerId', 
                      Manufacturer.Name AS 'ManufacturerName', Manufacturer.Notes AS 'ManufacturerNotes'
		FROM RecreationalRide INNER JOIN
                      Bike ON RecreationalRide.BikeId = Bike.Id INNER JOIN
                      BikeType ON Bike.TypeId = BikeType.Id INNER JOIN
                      Route ON RecreationalRide.RouteId = Route.Id INNER JOIN
                      RouteType ON Route.TypeId = RouteType.Id INNER JOIN
                      Manufacturer ON Bike.ManufacturerId = Manufacturer.Id
		WHERE [Date] BETWEEN @StartDate AND @EndDate

END

GO


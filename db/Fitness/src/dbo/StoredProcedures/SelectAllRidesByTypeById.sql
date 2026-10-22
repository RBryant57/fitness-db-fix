-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 3/2/2014
-- Description:	This stored procedure will select
--				all Rides of a particular type for a
--				given Id.
-- =============================================
CREATE PROCEDURE [dbo].[SelectAllRidesByTypeById]

	@RideType			int,
	@Id					int
	
AS
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    IF @RideType = 1
		SELECT TrainingRide.Id, TrainingRide.Date, TrainingRide.StartOdometer, TrainingRide.EndOdometer, TrainingRide.StartTime, TrainingRide.EndTime, 
                      TrainingRide.RideTimeHours, TrainingRide.RideTimeMinutes, TrainingRide.RideTimeSeconds, TrainingRide.AverageHR, TrainingRide.MaxHR, 
                      TrainingRide.AverageCadence, TrainingRide.ElevationGain, TrainingRide.MaxSpeed, TrainingRide.WindSpeed, TrainingRide.WindDirection, TrainingRide.Temperature, 
                      TrainingRide.Precipitation, TrainingRide.BikeId, TrainingRide.RouteId, COALESCE(TrainingRide.Notes, ''), Bike.Id AS 'BikeId', Bike.Name, 
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
		WHERE TrainingRide.Id = @Id

	IF @RideType = 2
		SELECT RecreationalRide.Id, RecreationalRide.Date, RecreationalRide.StartOdometer, RecreationalRide.EndOdometer, RecreationalRide.StartTime, RecreationalRide.EndTime, RecreationalRide.BikeEndTime,
                      RecreationalRide.RideTimeHours, RecreationalRide.RideTimeMinutes, RecreationalRide.RideTimeSeconds, RecreationalRide.BikeTimeHours, RecreationalRide.BikeTimeMinutes, 
					  RecreationalRide.BikeTimeSeconds, RecreationalRide.AverageHR, RecreationalRide.MaxHR, RecreationalRide.AverageCadence, RecreationalRide.ElevationGain, RecreationalRide.MaxSpeed, 
                      RecreationalRide.Wind, RecreationalRide.Temperature, RecreationalRide.Precipitation, RecreationalRide.BikeId, RecreationalRide.RouteId, COALESCE(RecreationalRide.Notes, ''), Bike.Id AS 'BikeId', Bike.Name, 
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
		WHERE RecreationalRide.Id = @Id

	IF @RideType = 3
		SELECT StationaryRide.Id, StationaryRide.Date, StationaryRide.StartOdometer, StationaryRide.EndOdometer, StationaryRide.StartTime, StationaryRide.EndTime, 
                      StationaryRide.RideTimeHours, StationaryRide.RideTimeMinutes, StationaryRide.RideTimeSeconds, StationaryRide.AverageHR, StationaryRide.MaxHR, 
                      StationaryRide.AverageCadence, 
                      StationaryRide.BikeId, COALESCE(StationaryRide.Notes, ''), Bike.Id AS 'BikeId', Bike.Name, 
                      Bike.ManufacturerId, Bike.TypeId, Bike.AcquisitionDate, Bike.BaseMiles, Bike.Notes AS 'BikeNotes', BikeType.Id AS 'BikeTypeId', BikeType.EnumId, 
                      BikeType.Name AS 'BikeTypeName', 
                      Manufacturer.Id AS 'ManufacturerId', Manufacturer.Name AS 'ManufacturerName', Manufacturer.Notes AS 'ManufacturerNotes'
		FROM StationaryRide LEFT OUTER JOIN
                      Bike ON StationaryRide.BikeId = Bike.Id INNER JOIN
                      BikeType ON Bike.TypeId = BikeType.Id INNER JOIN
                      Manufacturer ON Bike.ManufacturerId = Manufacturer.Id
		WHERE StationaryRide.Id = @Id
END

GO


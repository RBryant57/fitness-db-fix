CREATE VIEW dbo.TrainingRides
AS
SELECT        dbo.TrainingRide.Id, dbo.TrainingRide.Date AS [Ride Date], dbo.TrainingRide.StartTime AS [Starting Time], dbo.TrainingRide.EndTime AS [Ending Time], dbo.TrainingRide.RideTimeHours AS Hours, 
                         dbo.TrainingRide.RideTimeMinutes AS Minutes, dbo.TrainingRide.RideTimeSeconds AS Seconds, dbo.TrainingRide.EndOdometer - dbo.TrainingRide.StartOdometer AS [Stated Distance], dbo.TrainingRide.Distance, 
                         (dbo.TrainingRide.EndOdometer - dbo.TrainingRide.StartOdometer) * 1.0 / DATEDIFF(second, dbo.TrainingRide.StartTime, dbo.TrainingRide.EndTime) * 3600 AS Speed, DATEDIFF(second, dbo.TrainingRide.StartTime, 
                         dbo.TrainingRide.EndTime) / (dbo.TrainingRide.EndOdometer - dbo.TrainingRide.StartOdometer) / 60.0 AS Pace, dbo.TrainingRide.MaxSpeed AS [Maximum Speed], dbo.TrainingRide.AverageHR AS [Average HR], 
                         dbo.TrainingRide.MaxHR AS [Maximum HR], dbo.TrainingRide.AverageCadence AS [Average Cadence], dbo.TrainingRide.ElevationGain AS [Elevation Gain], dbo.TrainingRide.WindSpeed AS [Wind Speed], 
                         dbo.TrainingRide.WindDirection AS [Wind Direction], dbo.TrainingRide.Temperature, dbo.TrainingRide.Precipitation, dbo.Bike.Name AS [Bike Name], dbo.BikeType.Name AS [Bike Type], dbo.Route.Name AS [Route Name], 
                         dbo.Route.City, dbo.Route.State, dbo.RouteType.Name AS [Route Type], COALESCE (dbo.TrainingRide.Notes, '') AS Notes, CASE WHEN dbo.TrainingRide.GpxJsonId IS NULL THEN 'No' ELSE 'Yes' END AS [GPX?]
FROM            dbo.TrainingRide INNER JOIN
                         dbo.Bike ON dbo.TrainingRide.BikeId = dbo.Bike.Id INNER JOIN
                         dbo.BikeType ON dbo.Bike.TypeId = dbo.BikeType.Id INNER JOIN
                         dbo.Route ON dbo.TrainingRide.RouteId = dbo.Route.Id INNER JOIN
                         dbo.RouteType ON dbo.Route.TypeId = dbo.RouteType.Id INNER JOIN
                         dbo.Manufacturer ON dbo.Bike.ManufacturerId = dbo.Manufacturer.Id

GO


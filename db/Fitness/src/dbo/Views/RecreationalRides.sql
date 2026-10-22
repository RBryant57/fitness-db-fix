CREATE VIEW dbo.RecreationalRides
AS
SELECT        dbo.RecreationalRide.Id, dbo.RecreationalRide.Date AS [Ride Date], dbo.RecreationalRide.StartTime AS [Starting Time], dbo.RecreationalRide.EndTime AS [Ending Time], 
                         dbo.RecreationalRide.BikeEndTime AS [Bike Ending Time], dbo.RecreationalRide.RideTimeHours AS Hours, dbo.RecreationalRide.RideTimeMinutes AS Minutes, dbo.RecreationalRide.RideTimeSeconds AS Seconds, 
                         dbo.RecreationalRide.BikeTimeHours AS [Bike Hours], dbo.RecreationalRide.BikeTimeMinutes AS [Bike Minutes], dbo.RecreationalRide.BikeTimeSeconds AS [Bike Seconds], 
                         dbo.RecreationalRide.EndOdometer - dbo.RecreationalRide.StartOdometer AS [Stated Distance], dbo.RecreationalRide.Distance, (dbo.RecreationalRide.EndOdometer - dbo.RecreationalRide.StartOdometer) * 1.0 / DATEDIFF(second, dbo.RecreationalRide.StartTime, 
                         dbo.RecreationalRide.BikeEndTime) * 3600 AS Speed, DATEDIFF(second, dbo.RecreationalRide.StartTime, dbo.RecreationalRide.BikeEndTime) / (dbo.RecreationalRide.EndOdometer - dbo.RecreationalRide.StartOdometer) 
                         / 60.0 AS Pace, dbo.RecreationalRide.MaxSpeed AS [Maximum Speed], (dbo.RecreationalRide.EndOdometer - dbo.RecreationalRide.StartOdometer) * 1.0 / DATEDIFF(second, dbo.RecreationalRide.StartTime, 
                         dbo.RecreationalRide.EndTime) * 3600 AS [Overall Speed], DATEDIFF(second, dbo.RecreationalRide.StartTime, dbo.RecreationalRide.EndTime) / (dbo.RecreationalRide.EndOdometer - dbo.RecreationalRide.StartOdometer) 
                         / 60.0 AS [Overall Pace], dbo.RecreationalRide.AverageHR AS [Average HR], dbo.RecreationalRide.MaxHR AS [Maximum HR], dbo.RecreationalRide.AverageCadence AS [Average Cadence], 
                         dbo.RecreationalRide.ElevationGain AS [Elevation Gain], dbo.RecreationalRide.Wind, dbo.RecreationalRide.Temperature, dbo.RecreationalRide.Precipitation, dbo.Bike.Name AS [Bike Name], dbo.BikeType.Name AS [Bike Type], 
                         dbo.Route.Name AS [Route Name], dbo.Route.City, dbo.Route.State, dbo.RouteType.Name AS [Route Type], COALESCE (dbo.RecreationalRide.Notes, '') AS Notes, CASE WHEN dbo.RecreationalRide.GpxJsonId IS NULL 
                         THEN 'No' ELSE 'Yes' END AS [GPX?]
FROM            dbo.RecreationalRide INNER JOIN
                         dbo.Bike ON dbo.RecreationalRide.BikeId = dbo.Bike.Id INNER JOIN
                         dbo.BikeType ON dbo.Bike.TypeId = dbo.BikeType.Id INNER JOIN
                         dbo.Route ON dbo.RecreationalRide.RouteId = dbo.Route.Id INNER JOIN
                         dbo.RouteType ON dbo.Route.TypeId = dbo.RouteType.Id INNER JOIN
                         dbo.Manufacturer ON dbo.Bike.ManufacturerId = dbo.Manufacturer.Id

GO


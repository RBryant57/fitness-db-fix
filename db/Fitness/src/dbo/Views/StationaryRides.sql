
CREATE VIEW [dbo].[StationaryRides]
AS
SELECT        dbo.StationaryRide.Id, dbo.StationaryRide.Date AS [Ride Date], dbo.StationaryRide.StartTime AS [Starting Time], dbo.StationaryRide.EndTime AS [Ending Time], dbo.StationaryRide.RideTimeHours AS Hours, 
                         dbo.StationaryRide.RideTimeMinutes AS Minutes, dbo.StationaryRide.RideTimeSeconds AS Seconds, dbo.StationaryRide.EndOdometer - dbo.StationaryRide.StartOdometer AS Distance, 
                         (dbo.StationaryRide.EndOdometer - dbo.StationaryRide.StartOdometer) * 1.0 / DATEDIFF(second, dbo.StationaryRide.StartTime, dbo.StationaryRide.EndTime) * 3600 AS Speed, DATEDIFF(second, 
                         dbo.StationaryRide.StartTime, dbo.StationaryRide.EndTime) / (dbo.StationaryRide.EndOdometer - dbo.StationaryRide.StartOdometer) / 60.0 AS Pace, dbo.StationaryRide.AverageHR AS [Average HR], 
                         dbo.StationaryRide.MaxHR AS [Maximum HR], dbo.StationaryRide.AverageCadence AS [Average Cadence], COALESCE (dbo.StationaryRide.Notes, '') AS Notes, dbo.Bike.Name AS [Bike Name], 
                         dbo.BikeType.Name AS [Bike Type]
FROM            dbo.BikeType INNER JOIN
                         dbo.Bike ON dbo.BikeType.Id = dbo.Bike.TypeId RIGHT OUTER JOIN
                         dbo.StationaryRide ON dbo.Bike.Id = dbo.StationaryRide.BikeId

GO


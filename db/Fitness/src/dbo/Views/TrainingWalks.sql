CREATE VIEW dbo.TrainingWalks
AS
SELECT        dbo.TrainingWalk.Id, dbo.TrainingWalk.Date AS [Walk Date], dbo.TrainingWalk.StartTime AS [Starting Time], dbo.TrainingWalk.EndTime AS [Ending Time], dbo.TrainingWalk.WalkTimeHours AS Hours, 
                         dbo.TrainingWalk.WalkTimeMinutes AS Minutes, dbo.TrainingWalk.WalkTimeSeconds AS Seconds, dbo.TrainingWalk.Distance, dbo.TrainingWalk.Distance / DATEDIFF(second, dbo.TrainingWalk.StartTime, 
                         dbo.TrainingWalk.EndTime) * 3600 AS Speed, DATEDIFF(second, dbo.TrainingWalk.StartTime, dbo.TrainingWalk.EndTime) / dbo.TrainingWalk.Distance / 60 AS Pace, dbo.TrainingWalk.MaxSpeed AS [Maximum Speed], 
                         dbo.TrainingWalk.AverageHR AS [Average HR], dbo.TrainingWalk.MaxHR AS [Maximum HR], dbo.TrainingWalk.ElevationGain AS [Elevation Gain], dbo.TrainingWalk.WindSpeed AS [Wind Speed], 
                         dbo.TrainingWalk.WindDirection AS [Wind Direction], dbo.TrainingWalk.Temperature, dbo.TrainingWalk.Precipitation, dbo.Shoe.Name AS [Shoe Name], dbo.ShoeType.Name AS [Shoe Type], dbo.Route.Name AS [Route Name], 
                         dbo.Route.City, dbo.Route.State, dbo.RouteType.Name AS [Route Type], COALESCE (dbo.TrainingWalk.Notes, '') AS Notes, CASE WHEN dbo.TrainingWalk.GpxJsonId IS NULL THEN 'No' ELSE 'Yes' END AS [GPX?]
FROM            dbo.TrainingWalk INNER JOIN
                         dbo.Route ON dbo.TrainingWalk.RouteId = dbo.Route.Id INNER JOIN
                         dbo.RouteType ON dbo.Route.TypeId = dbo.RouteType.Id INNER JOIN
                         dbo.Shoe ON dbo.TrainingWalk.ShoeId = dbo.Shoe.Id INNER JOIN
                         dbo.ShoeType ON dbo.Shoe.ShoeTypeId = dbo.ShoeType.Id

GO


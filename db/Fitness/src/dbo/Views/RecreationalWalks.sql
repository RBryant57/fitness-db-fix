CREATE VIEW dbo.RecreationalWalks
AS
SELECT        dbo.RecreationalWalk.Id, dbo.RecreationalWalk.Date AS [Walk Date], dbo.RecreationalWalk.StartTime AS [Starting Time], dbo.RecreationalWalk.EndTime AS [Ending Time], 
                         dbo.RecreationalWalk.PathEndTime AS [Path Ending Time], dbo.RecreationalWalk.WalkTimeHours AS Hours, dbo.RecreationalWalk.WalkTimeMinutes AS Minutes, dbo.RecreationalWalk.WalkTimeSeconds AS Seconds, 
                         dbo.RecreationalWalk.PathTimeHours AS [Path Hours], dbo.RecreationalWalk.PathTimeMinutes AS [Path Minutes], dbo.RecreationalWalk.PathTimeSeconds AS [Path Seconds], dbo.RecreationalWalk.Distance, 
                         dbo.RecreationalWalk.Distance / DATEDIFF(second, dbo.RecreationalWalk.StartTime, dbo.RecreationalWalk.EndTime) * 3600 AS Speed, DATEDIFF(second, dbo.RecreationalWalk.StartTime, dbo.RecreationalWalk.EndTime) 
                         / dbo.RecreationalWalk.Distance / 60.0 AS Pace, dbo.RecreationalWalk.Distance / DATEDIFF(second, dbo.RecreationalWalk.StartTime, dbo.RecreationalWalk.PathEndTime) * 3600 AS [Overall Speed], DATEDIFF(second, 
                         dbo.RecreationalWalk.StartTime, dbo.RecreationalWalk.PathEndTime) / dbo.RecreationalWalk.Distance / 60.0 AS [Overall Pace], dbo.RecreationalWalk.MaxSpeed AS [Maximum Speed], 
                         dbo.RecreationalWalk.AverageHR AS [Average HR], dbo.RecreationalWalk.MaxHR AS [Maximum HR], dbo.RecreationalWalk.ElevationGain AS [Elevation Gain], dbo.RecreationalWalk.Wind, dbo.RecreationalWalk.Temperature, 
                         dbo.RecreationalWalk.Precipitation, dbo.Shoe.Name AS [Shoe Name], dbo.ShoeType.Name AS [Shoe Type], dbo.Route.Name AS [Route Name], dbo.Route.City, dbo.Route.State, dbo.RouteType.Name AS [Route Type], 
                         COALESCE (dbo.RecreationalWalk.Notes, '') AS Notes, CASE WHEN dbo.RecreationalWalk.GpxJsonId IS NULL THEN 'No' ELSE 'Yes' END AS [GPX?]
FROM            dbo.RecreationalWalk INNER JOIN
                         dbo.Route ON dbo.RecreationalWalk.RouteId = dbo.Route.Id INNER JOIN
                         dbo.RouteType ON dbo.Route.TypeId = dbo.RouteType.Id INNER JOIN
                         dbo.Shoe ON dbo.RecreationalWalk.ShoeId = dbo.Shoe.Id INNER JOIN
                         dbo.ShoeType ON dbo.Shoe.ShoeTypeId = dbo.ShoeType.Id

GO


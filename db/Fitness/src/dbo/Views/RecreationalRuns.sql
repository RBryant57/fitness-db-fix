CREATE VIEW dbo.RecreationalRuns
AS
SELECT        dbo.RecreationalRun.Id, dbo.RecreationalRun.Date AS [Run Date], dbo.RecreationalRun.StartTime AS [Starting Time], dbo.RecreationalRun.EndTime AS [Ending Time], dbo.RecreationalRun.PathEndTime AS [Path Ending Time], 
                         dbo.RecreationalRun.RunTimeHours AS Hours, dbo.RecreationalRun.RunTimeMinutes AS Minutes, dbo.RecreationalRun.RunTimeSeconds AS Seconds, dbo.RecreationalRun.PathTimeHours AS [Path Hours], 
                         dbo.RecreationalRun.PathTimeMinutes AS [Path Minutes], dbo.RecreationalRun.PathTimeSeconds AS [Path Seconds], dbo.RecreationalRun.Distance, dbo.RecreationalRun.Distance / DATEDIFF(second, 
                         dbo.RecreationalRun.StartTime, dbo.RecreationalRun.EndTime) * 3600 AS Speed, DATEDIFF(second, dbo.RecreationalRun.StartTime, dbo.RecreationalRun.EndTime) / dbo.RecreationalRun.Distance / 60.0 AS Pace, 
                         dbo.RecreationalRun.Distance / DATEDIFF(second, dbo.RecreationalRun.StartTime, dbo.RecreationalRun.PathEndTime) * 3600 AS [Overall Speed], DATEDIFF(second, dbo.RecreationalRun.StartTime, 
                         dbo.RecreationalRun.PathEndTime) / dbo.RecreationalRun.Distance / 60.0 AS [Overall Pace], dbo.RecreationalRun.MaxSpeed AS [Maximum Speed], dbo.RecreationalRun.AverageHR AS [Average HR], 
                         dbo.RecreationalRun.MaxHR AS [Maximum HR], dbo.RecreationalRun.ElevationGain AS [Elevation Gain], dbo.RecreationalRun.Wind, dbo.RecreationalRun.Temperature, dbo.RecreationalRun.Precipitation, 
                         dbo.Shoe.Name AS [Shoe Name], dbo.ShoeType.Name AS [Shoe Type], dbo.Route.Name AS [Route Name], dbo.Route.City, dbo.Route.State, dbo.RouteType.Name AS [Route Type], COALESCE (dbo.RecreationalRun.Notes, '') 
                         AS Notes, CASE WHEN dbo.RecreationalRun.GpxJsonId IS NULL THEN 'No' ELSE 'Yes' END AS [GPX?]
FROM            dbo.RecreationalRun INNER JOIN
                         dbo.Route ON dbo.RecreationalRun.RouteId = dbo.Route.Id INNER JOIN
                         dbo.RouteType ON dbo.Route.TypeId = dbo.RouteType.Id INNER JOIN
                         dbo.Shoe ON dbo.RecreationalRun.ShoeId = dbo.Shoe.Id INNER JOIN
                         dbo.ShoeType ON dbo.Shoe.ShoeTypeId = dbo.ShoeType.Id

GO


CREATE VIEW dbo.TrainingRuns
AS
SELECT        dbo.TrainingRun.Id, dbo.TrainingRun.Date AS [Run Date], dbo.TrainingRun.StartTime AS [Starting Time], dbo.TrainingRun.EndTime AS [Ending Time], dbo.TrainingRun.RunTimeHours AS Hours, 
                         dbo.TrainingRun.RunTimeMinutes AS Minutes, dbo.TrainingRun.RunTimeSeconds AS Seconds, dbo.TrainingRun.Distance, dbo.TrainingRun.Distance / DATEDIFF(second, dbo.TrainingRun.StartTime, dbo.TrainingRun.EndTime) 
                         * 3600 AS Speed, DATEDIFF(second, dbo.TrainingRun.StartTime, dbo.TrainingRun.EndTime) / dbo.TrainingRun.Distance / 60 AS Pace, dbo.TrainingRun.MaxSpeed AS [Maximum Speed], 
                         dbo.TrainingRun.AverageHR AS [Average HR], dbo.TrainingRun.MaxHR AS [Maximum HR], dbo.TrainingRun.ElevationGain AS [Elevation Gain], dbo.TrainingRun.WindSpeed AS [Wind Speed], 
                         dbo.TrainingRun.WindDirection AS [Wind Direction], dbo.TrainingRun.Temperature, dbo.TrainingRun.Precipitation, dbo.Shoe.Name AS [Shoe Name], dbo.ShoeType.Name AS [Shoe Type], dbo.Route.Name AS [Route Name], 
                         dbo.Route.City, dbo.Route.State, dbo.RouteType.Name AS [Route Type], COALESCE (dbo.TrainingRun.Notes, '') AS Notes, CASE WHEN dbo.TrainingRun.GpxJsonId IS NULL THEN 'No' ELSE 'Yes' END AS [GPX?]
FROM            dbo.TrainingRun INNER JOIN
                         dbo.Route ON dbo.TrainingRun.RouteId = dbo.Route.Id INNER JOIN
                         dbo.RouteType ON dbo.Route.TypeId = dbo.RouteType.Id INNER JOIN
                         dbo.Shoe ON dbo.TrainingRun.ShoeId = dbo.Shoe.Id INNER JOIN
                         dbo.ShoeType ON dbo.Shoe.ShoeTypeId = dbo.ShoeType.Id

GO


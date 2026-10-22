
CREATE VIEW [dbo].[TreadmillRuns]
AS
SELECT        dbo.TreadmillRun.Id, dbo.TreadmillRun.Date AS [Run Date], dbo.TreadmillRun.StartTime AS [Starting Time], dbo.TreadmillRun.EndTime AS [Ending Time], dbo.TreadmillRun.RunTimeHours AS Hours, 
                         dbo.TreadmillRun.RunTimeMinutes AS Minutes, dbo.TreadmillRun.RunTimeSeconds AS Seconds, dbo.TreadmillRun.Distance, dbo.TreadmillRun.Distance / DATEDIFF(second, dbo.TreadmillRun.StartTime, 
                         dbo.TreadmillRun.EndTime) * 3600 AS Speed, DATEDIFF(second, dbo.TreadmillRun.StartTime, dbo.TreadmillRun.EndTime) / dbo.TreadmillRun.Distance / 60.0 AS Pace, 
                         dbo.TreadmillRun.AverageHR AS [Average HR], dbo.TreadmillRun.MaxHR AS [Maximum HR], dbo.TreadmillRun.ElevationGain AS [Elevation Gain], dbo.Shoe.Name AS [Shoe Name], 
                         dbo.ShoeType.Name AS [Shoe Type], COALESCE (dbo.TreadmillRun.Notes, '') AS Notes
FROM            dbo.TreadmillRun INNER JOIN
                         dbo.Shoe ON dbo.TreadmillRun.ShoeId = dbo.Shoe.Id INNER JOIN
                         dbo.ShoeType ON dbo.Shoe.ShoeTypeId = dbo.ShoeType.Id

GO


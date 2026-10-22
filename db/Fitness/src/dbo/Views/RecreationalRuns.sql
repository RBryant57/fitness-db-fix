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

EXECUTE sp_addextendedproperty @name = N'MS_DiagramPane2', @value = N'dth = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
      End
   End
   Begin CriteriaPane = 
      Begin ColumnWidths = 11
         Column = 7515
         Alias = 2085
         Table = 1170
         Output = 720
         Append = 1400
         NewValue = 1170
         SortType = 1350
         SortOrder = 1410
         GroupBy = 1350
         Filter = 1350
         Or = 1350
         Or = 1350
         Or = 1350
      End
   End
End
', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'RecreationalRuns';


GO

EXECUTE sp_addextendedproperty @name = N'MS_DiagramPaneCount', @value = 2, @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'RecreationalRuns';


GO

EXECUTE sp_addextendedproperty @name = N'MS_DiagramPane1', @value = N'[0E232FF0-B466-11cf-A24F-00AA00A3EFFF, 1.00]
Begin DesignProperties = 
   Begin PaneConfigurations = 
      Begin PaneConfiguration = 0
         NumPanes = 4
         Configuration = "(H (1[40] 4[20] 2[20] 3) )"
      End
      Begin PaneConfiguration = 1
         NumPanes = 3
         Configuration = "(H (1 [50] 4 [25] 3))"
      End
      Begin PaneConfiguration = 2
         NumPanes = 3
         Configuration = "(H (1 [50] 2 [25] 3))"
      End
      Begin PaneConfiguration = 3
         NumPanes = 3
         Configuration = "(H (4 [30] 2 [40] 3))"
      End
      Begin PaneConfiguration = 4
         NumPanes = 2
         Configuration = "(H (1 [56] 3))"
      End
      Begin PaneConfiguration = 5
         NumPanes = 2
         Configuration = "(H (2 [66] 3))"
      End
      Begin PaneConfiguration = 6
         NumPanes = 2
         Configuration = "(H (4 [50] 3))"
      End
      Begin PaneConfiguration = 7
         NumPanes = 1
         Configuration = "(V (3))"
      End
      Begin PaneConfiguration = 8
         NumPanes = 3
         Configuration = "(H (1[56] 4[18] 2) )"
      End
      Begin PaneConfiguration = 9
         NumPanes = 2
         Configuration = "(H (1 [75] 4))"
      End
      Begin PaneConfiguration = 10
         NumPanes = 2
         Configuration = "(H (1[66] 2) )"
      End
      Begin PaneConfiguration = 11
         NumPanes = 2
         Configuration = "(H (4 [60] 2))"
      End
      Begin PaneConfiguration = 12
         NumPanes = 1
         Configuration = "(H (1) )"
      End
      Begin PaneConfiguration = 13
         NumPanes = 1
         Configuration = "(V (4))"
      End
      Begin PaneConfiguration = 14
         NumPanes = 1
         Configuration = "(V (2))"
      End
      ActivePaneConfig = 0
   End
   Begin DiagramPane = 
      Begin Origin = 
         Top = 0
         Left = 0
      End
      Begin Tables = 
         Begin Table = "RecreationalRun"
            Begin Extent = 
               Top = 6
               Left = 38
               Bottom = 123
               Right = 211
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "Route"
            Begin Extent = 
               Top = 6
               Left = 249
               Bottom = 123
               Right = 409
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "RouteType"
            Begin Extent = 
               Top = 6
               Left = 447
               Bottom = 108
               Right = 607
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "Shoe"
            Begin Extent = 
               Top = 108
               Left = 447
               Bottom = 225
               Right = 611
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "ShoeType"
            Begin Extent = 
               Top = 6
               Left = 645
               Bottom = 110
               Right = 805
            End
            DisplayFlags = 280
            TopColumn = 0
         End
      End
   End
   Begin SQLPane = 
   End
   Begin DataPane = 
      Begin ParameterDefaults = ""
      End
      Begin ColumnWidths = 30
         Width = 284
         Width = 1500
         Width = 1500
         Width = 2355
         Width = 1800
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Wi', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'RecreationalRuns';


GO


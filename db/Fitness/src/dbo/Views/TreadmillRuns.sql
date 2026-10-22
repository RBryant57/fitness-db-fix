
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
      End
   End
   Begin SQLPane = 
   End
   Begin DataPane = 
      Begin ParameterDefaults = ""
      End
      Begin ColumnWidths = 9
         Width = 284
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
         Column = 1440
         Alias = 900
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
      End', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'TreadmillRuns';


GO


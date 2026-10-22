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

EXECUTE sp_addextendedproperty @name = N'MS_DiagramPaneCount', @value = 2, @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'RecreationalRides';


GO

EXECUTE sp_addextendedproperty @name = N'MS_DiagramPane1', @value = N'[0E232FF0-B466-11cf-A24F-00AA00A3EFFF, 1.00]
Begin DesignProperties = 
   Begin PaneConfigurations = 
      Begin PaneConfiguration = 0
         NumPanes = 4
         Configuration = "(H (1[31] 4[31] 2[20] 3) )"
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
         Top = -192
         Left = 0
      End
      Begin Tables = 
         Begin Table = "RecreationalRide"
            Begin Extent = 
               Top = 6
               Left = 38
               Bottom = 123
               Right = 210
            End
            DisplayFlags = 280
            TopColumn = 23
         End
         Begin Table = "Bike"
            Begin Extent = 
               Top = 6
               Left = 248
               Bottom = 123
               Right = 412
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "BikeType"
            Begin Extent = 
               Top = 6
               Left = 450
               Bottom = 108
               Right = 610
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "Route"
            Begin Extent = 
               Top = 108
               Left = 450
               Bottom = 225
               Right = 610
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "RouteType"
            Begin Extent = 
               Top = 126
               Left = 38
               Bottom = 228
               Right = 198
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "Manufacturer"
            Begin Extent = 
               Top = 126
               Left = 236
               Bottom = 228
               Right = 396
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
      Begin ColumnWidths = 47
         Width = 284
         Width = 1500
         Widt', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'RecreationalRides';


GO

EXECUTE sp_addextendedproperty @name = N'MS_DiagramPane2', @value = N'h = 1500
         Width = 1890
         Width = 2520
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
         Column = 9375
         Alias = 3045
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
', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'RecreationalRides';


GO


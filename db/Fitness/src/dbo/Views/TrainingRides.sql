CREATE VIEW dbo.TrainingRides
AS
SELECT        dbo.TrainingRide.Id, dbo.TrainingRide.Date AS [Ride Date], dbo.TrainingRide.StartTime AS [Starting Time], dbo.TrainingRide.EndTime AS [Ending Time], dbo.TrainingRide.RideTimeHours AS Hours, 
                         dbo.TrainingRide.RideTimeMinutes AS Minutes, dbo.TrainingRide.RideTimeSeconds AS Seconds, dbo.TrainingRide.EndOdometer - dbo.TrainingRide.StartOdometer AS [Stated Distance], dbo.TrainingRide.Distance, 
                         (dbo.TrainingRide.EndOdometer - dbo.TrainingRide.StartOdometer) * 1.0 / DATEDIFF(second, dbo.TrainingRide.StartTime, dbo.TrainingRide.EndTime) * 3600 AS Speed, DATEDIFF(second, dbo.TrainingRide.StartTime, 
                         dbo.TrainingRide.EndTime) / (dbo.TrainingRide.EndOdometer - dbo.TrainingRide.StartOdometer) / 60.0 AS Pace, dbo.TrainingRide.MaxSpeed AS [Maximum Speed], dbo.TrainingRide.AverageHR AS [Average HR], 
                         dbo.TrainingRide.MaxHR AS [Maximum HR], dbo.TrainingRide.AverageCadence AS [Average Cadence], dbo.TrainingRide.ElevationGain AS [Elevation Gain], dbo.TrainingRide.WindSpeed AS [Wind Speed], 
                         dbo.TrainingRide.WindDirection AS [Wind Direction], dbo.TrainingRide.Temperature, dbo.TrainingRide.Precipitation, dbo.Bike.Name AS [Bike Name], dbo.BikeType.Name AS [Bike Type], dbo.Route.Name AS [Route Name], 
                         dbo.Route.City, dbo.Route.State, dbo.RouteType.Name AS [Route Type], COALESCE (dbo.TrainingRide.Notes, '') AS Notes, CASE WHEN dbo.TrainingRide.GpxJsonId IS NULL THEN 'No' ELSE 'Yes' END AS [GPX?]
FROM            dbo.TrainingRide INNER JOIN
                         dbo.Bike ON dbo.TrainingRide.BikeId = dbo.Bike.Id INNER JOIN
                         dbo.BikeType ON dbo.Bike.TypeId = dbo.BikeType.Id INNER JOIN
                         dbo.Route ON dbo.TrainingRide.RouteId = dbo.Route.Id INNER JOIN
                         dbo.RouteType ON dbo.Route.TypeId = dbo.RouteType.Id INNER JOIN
                         dbo.Manufacturer ON dbo.Bike.ManufacturerId = dbo.Manufacturer.Id

GO

EXECUTE sp_addextendedproperty @name = N'MS_DiagramPane2', @value = N'00
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
         Column = 4170
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
      End
   End
End
', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'TrainingRides';


GO

EXECUTE sp_addextendedproperty @name = N'MS_DiagramPaneCount', @value = 2, @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'TrainingRides';


GO

EXECUTE sp_addextendedproperty @name = N'MS_DiagramPane1', @value = N'[0E232FF0-B466-11cf-A24F-00AA00A3EFFF, 1.00]
Begin DesignProperties = 
   Begin PaneConfigurations = 
      Begin PaneConfiguration = 0
         NumPanes = 4
         Configuration = "(H (1[41] 4[25] 2[16] 3) )"
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
         Top = -96
         Left = 0
      End
      Begin Tables = 
         Begin Table = "TrainingRide"
            Begin Extent = 
               Top = 6
               Left = 38
               Bottom = 123
               Right = 210
            End
            DisplayFlags = 280
            TopColumn = 6
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
      Begin ColumnWidths = 44
         Width = 284
         Width = 1500
         Width = 15', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'TrainingRides';


GO


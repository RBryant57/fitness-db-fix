-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 7/26/2014
-- Description:	This stored procedure will select
--				all Runs of a particular type for a
--				given Id.
-- =============================================
CREATE PROCEDURE [dbo].[SelectAllRunsByTypeById]

	@RunType			int,
	@Id					int
	
AS
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    IF @RunType = 1
		SELECT TrainingRun.Id, TrainingRun.Date, TrainingRun.Distance, TrainingRun.StartTime, TrainingRun.EndTime, 
                      TrainingRun.RunTimeHours, TrainingRun.RunTimeMinutes, TrainingRun.RunTimeSeconds, TrainingRun.AverageHR, TrainingRun.MaxHR, 
                      TrainingRun.ElevationGain, TrainingRun.WindSpeed, TrainingRun.WindDirection, TrainingRun.Temperature, 
                      TrainingRun.Precipitation, TrainingRun.ShoeId, TrainingRun.RouteId, COALESCE(TrainingRun.Notes, ''), Shoe.Id AS 'ShoeId', Shoe.Name, 
                      Shoe.ManufacturerId, Shoe.AcquisitionDate, Shoe.Notes AS 'ShoeNotes',  
                      Route.Id AS 'RouteId', Route.Name AS 'RouteName', Route.City, Route.State, Route.TypeId AS 'RouteTypeId', Route.Rating, 
                      Route.Notes AS 'RouteNotes', RouteType.Id AS 'RouteTypeId', RouteType.EnumId AS 'RouteTypeEnumId', RouteType.Name AS 'RouteTypeName', Manufacturer.Id AS 'ManufacturerId', 
                      Manufacturer.Name AS 'ManufacturerName', Manufacturer.Notes AS 'ManufacturerNotes'
		FROM TrainingRun INNER JOIN
                      Shoe ON TrainingRun.ShoeId = Shoe.Id INNER JOIN
                      Route ON TrainingRun.RouteId = Route.Id INNER JOIN
                      RouteType ON Route.TypeId = RouteType.Id INNER JOIN
                      Manufacturer ON Shoe.ManufacturerId = Manufacturer.Id
		WHERE TrainingRun.Id = @Id

	IF @RunType = 2
		SELECT RecreationalRun.Id, RecreationalRun.Date, RecreationalRun.Distance, RecreationalRun.StartTime, RecreationalRun.EndTime, RecreationalRun.PathEndTime,
                      RecreationalRun.RunTimeHours, RecreationalRun.RunTimeMinutes, RecreationalRun.RunTimeSeconds, RecreationalRun.PathTimeHours, RecreationalRun.PathTimeMinutes, 
					  RecreationalRun.PathTimeSeconds, RecreationalRun.AverageHR, RecreationalRun.MaxHR, RecreationalRun.ElevationGain, RecreationalRun.MaxSpeed, 
                      RecreationalRun.Wind, RecreationalRun.Temperature, RecreationalRun.Precipitation, RecreationalRun.ShoeId, RecreationalRun.RouteId, COALESCE(RecreationalRun.Notes, ''), Shoe.Id AS 'ShoeId', Shoe.Name, 
                      Shoe.ManufacturerId, Shoe.AcquisitionDate, Shoe.Notes AS 'ShoeNotes', 
                      Route.Id AS 'RouteId', Route.Name AS 'RouteName', Route.City, Route.State, Route.TypeId AS 'RouteTypeId', Route.Rating, 
                      Route.Notes AS 'RouteNotes', RouteType.Id AS 'RouteTypeId', RouteType.EnumId AS 'RouteTypeEnumId', RouteType.Name AS 'RouteTypeName', Manufacturer.Id AS 'ManufacturerId', 
                      Manufacturer.Name AS 'ManufacturerName', Manufacturer.Notes AS 'ManufacturerNotes'
		FROM RecreationalRun INNER JOIN
                      Shoe ON RecreationalRun.ShoeId = Shoe.Id INNER JOIN
                      Route ON RecreationalRun.RouteId = Route.Id INNER JOIN
                      RouteType ON Route.TypeId = RouteType.Id INNER JOIN
                      Manufacturer ON Shoe.ManufacturerId = Manufacturer.Id
		WHERE RecreationalRun.Id = @Id

	IF @RunType = 3
		SELECT TreadmillRun.Id, TreadmillRun.Date, TreadmillRun.Distance, TreadmillRun.StartTime, TreadmillRun.EndTime, 
                      TreadmillRun.RunTimeHours, TreadmillRun.RunTimeMinutes, TreadmillRun.RunTimeSeconds,  
					  TreadmillRun.AverageHR, TreadmillRun.MaxHR, TreadmillRun.ElevationGain,  
                      TreadmillRun.ShoeId, COALESCE(TreadmillRun.Notes, ''), Shoe.Id AS 'ShoeId', Shoe.Name, 
                      Shoe.ManufacturerId, Shoe.AcquisitionDate, Shoe.Notes AS 'ShoeNotes', 
                      Manufacturer.Id AS 'ManufacturerId', Manufacturer.Name AS 'ManufacturerName', Manufacturer.Notes AS 'ManufacturerNotes'
		FROM TreadmillRun INNER JOIN
                      Shoe ON TreadmillRun.ShoeId = Shoe.Id INNER JOIN
                      Manufacturer ON Shoe.ManufacturerId = Manufacturer.Id
		WHERE TreadmillRun.Id = @Id

END

GO


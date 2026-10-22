



-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 7/26/2014
-- Description:	This stored procedure will select
--				all Walks of a particular type for a
--				given Id.
-- =============================================
CREATE PROCEDURE [dbo].[SelectAllWalksByTypeById]

	@WalkType			int,
	@Id					int
	
AS
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    IF @WalkType = 1
		SELECT TrainingWalk.Id, TrainingWalk.Date, TrainingWalk.Distance, TrainingWalk.StartTime, TrainingWalk.EndTime, 
                      TrainingWalk.WalkTimeHours, TrainingWalk.WalkTimeMinutes, TrainingWalk.WalkTimeSeconds, TrainingWalk.AverageHR, TrainingWalk.MaxHR, 
                      TrainingWalk.ElevationGain, TrainingWalk.WindSpeed, TrainingWalk.WindDirection, TrainingWalk.Temperature, 
                      TrainingWalk.Precipitation, TrainingWalk.ShoeId, TrainingWalk.RouteId, COALESCE(TrainingWalk.Notes, ''), Shoe.Id AS 'ShoeId', Shoe.Name, 
                      Shoe.ManufacturerId, Shoe.AcquisitionDate, Shoe.Notes AS 'ShoeNotes',  
                      Route.Id AS 'RouteId', Route.Name AS 'RouteName', Route.City, Route.State, Route.TypeId AS 'RouteTypeId', Route.Rating, 
                      Route.Notes AS 'RouteNotes', RouteType.Id AS 'RouteTypeId', RouteType.EnumId AS 'RouteTypeEnumId', RouteType.Name AS 'RouteTypeName', Manufacturer.Id AS 'ManufacturerId', 
                      Manufacturer.Name AS 'ManufacturerName', Manufacturer.Notes AS 'ManufacturerNotes'
		FROM TrainingWalk INNER JOIN
                      Shoe ON TrainingWalk.ShoeId = Shoe.Id INNER JOIN
                      Route ON TrainingWalk.RouteId = Route.Id INNER JOIN
                      RouteType ON Route.TypeId = RouteType.Id INNER JOIN
                      Manufacturer ON Shoe.ManufacturerId = Manufacturer.Id
		WHERE TrainingWalk.Id = @Id

	IF @WalkType = 2
		SELECT RecreationalWalk.Id, RecreationalWalk.Date, RecreationalWalk.Distance, RecreationalWalk.StartTime, RecreationalWalk.EndTime, RecreationalWalk.PathEndTime,
                      RecreationalWalk.WalkTimeHours, RecreationalWalk.WalkTimeMinutes, RecreationalWalk.WalkTimeSeconds, RecreationalWalk.PathTimeHours, RecreationalWalk.PathTimeMinutes, 
					  RecreationalWalk.PathTimeSeconds, RecreationalWalk.AverageHR, RecreationalWalk.MaxHR, RecreationalWalk.ElevationGain, RecreationalWalk.MaxSpeed, 
                      RecreationalWalk.Wind, RecreationalWalk.Temperature, RecreationalWalk.Precipitation, RecreationalWalk.ShoeId, RecreationalWalk.RouteId, COALESCE(RecreationalWalk.Notes, ''), Shoe.Id AS 'ShoeId', Shoe.Name, 
                      Shoe.ManufacturerId, Shoe.AcquisitionDate, Shoe.Notes AS 'ShoeNotes', 
                      Route.Id AS 'RouteId', Route.Name AS 'RouteName', Route.City, Route.State, Route.TypeId AS 'RouteTypeId', Route.Rating, 
                      Route.Notes AS 'RouteNotes', RouteType.Id AS 'RouteTypeId', RouteType.EnumId AS 'RouteTypeEnumId', RouteType.Name AS 'RouteTypeName', Manufacturer.Id AS 'ManufacturerId', 
                      Manufacturer.Name AS 'ManufacturerName', Manufacturer.Notes AS 'ManufacturerNotes'
		FROM RecreationalWalk INNER JOIN
                      Shoe ON RecreationalWalk.ShoeId = Shoe.Id INNER JOIN
                      Route ON RecreationalWalk.RouteId = Route.Id INNER JOIN
                      RouteType ON Route.TypeId = RouteType.Id INNER JOIN
                      Manufacturer ON Shoe.ManufacturerId = Manufacturer.Id
		WHERE RecreationalWalk.Id = @Id

END

GO


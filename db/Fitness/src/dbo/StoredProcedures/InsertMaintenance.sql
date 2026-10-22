



-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 8/3/06
-- Description:	Inserts a maintenance operation.
-- =============================================
CREATE PROCEDURE [dbo].[InsertMaintenance]
	
	@BikeId					int,
	@PartId					int,
	@ActionTaken			nvarchar(50),
	@Date					datetime,
	@Odometer				int,
	@Notes					text = ''

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    INSERT INTO
		Maintenance
	VALUES(@BikeId, @PartId, @ActionTaken, @Date, @Odometer, @Notes)

SELECT @@Identity

END

GO


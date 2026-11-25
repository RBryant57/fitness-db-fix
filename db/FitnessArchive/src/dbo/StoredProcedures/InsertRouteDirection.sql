
-- dbo.InsertRouteDirection
-- Changes:
--   * SELECT @@IDENTITY replaced by SCOPE_IDENTITY(), returned as an int column named Id.
--   * @DirectionDescription nvarchar(max) to match the column (was text -> implicit conversion);
--     @DirectionMileMarker decimal(18,1) to match the column.
--   * Explicit column list; transaction + TRY/CATCH.
CREATE   PROCEDURE dbo.InsertRouteDirection
    @RouteId              int,
    @DirectionNumber      int,
    @DirectionMileMarker  decimal(18,1),
    @DirectionDescription nvarchar(max)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NewId int;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.RouteDirection
            (RouteId, DirectionNumber, DirectionMileMarker, DirectionDescription)
        VALUES
            (@RouteId, @DirectionNumber, @DirectionMileMarker, @DirectionDescription);

        SET @NewId = CAST(SCOPE_IDENTITY() AS int);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    SELECT @NewId AS Id;
END;

GO


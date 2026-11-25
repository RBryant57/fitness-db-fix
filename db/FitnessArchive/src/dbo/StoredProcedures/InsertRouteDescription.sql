
-- dbo.InsertRouteDescription
-- Changes:
--   * SELECT @@IDENTITY replaced by SCOPE_IDENTITY(), returned as an int column named Id.
--   * Explicit column list; @Description varchar(max) instead of text; transaction + TRY/CATCH.
CREATE   PROCEDURE dbo.InsertRouteDescription
    @RouteId     int,
    @Description varchar(max)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NewId int;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.RouteDisplay
            (RouteId, [Description])
        VALUES
            (@RouteId, @Description);

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


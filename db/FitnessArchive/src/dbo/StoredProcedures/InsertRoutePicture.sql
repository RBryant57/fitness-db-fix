
-- dbo.InsertRoutePicture
-- Changes:
--   * SELECT @@IDENTITY replaced by SCOPE_IDENTITY(), returned as an int column named Id.
--   * Explicit column list; @ImageDescription varchar(max) (column is NOT NULL text, so the empty-string default is kept).
--   * Transaction + TRY/CATCH.
CREATE   PROCEDURE dbo.InsertRoutePicture
    @RouteId          int,
    @ImageFileName    nvarchar(100),
    @ImageDescription varchar(max) = ''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NewId int;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.RoutePicture
            (RouteId, ImageFileName, ImageDescription)
        VALUES
            (@RouteId, @ImageFileName, @ImageDescription);

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


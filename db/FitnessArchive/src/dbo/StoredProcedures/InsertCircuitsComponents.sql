
-- dbo.InsertCircuitsComponents
-- Changes:
--   * Transaction + TRY/CATCH; now returns the new Id (previously returned nothing).
CREATE   PROCEDURE dbo.InsertCircuitsComponents
    @CircuitId          int,
    @CircuitComponentId int
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NewId int;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.CircuitsComponents
            (CircuitId, CircuitComponentId)
        VALUES
            (@CircuitId, @CircuitComponentId);

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


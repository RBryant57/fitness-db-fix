
-- dbo.InsertRecreationalWalkGPX
-- Changes:
--   * @Notes now defaults to NULL (was '').
--   * BUG: a `GRANT EXECUTE ... TO [FitnessLogger]` had been pasted into the procedure body (no GO), so it re-ran
--     on every call and failed for callers without GRANT rights. Removed.
--   * Explicit column list; @Notes nvarchar(max) (column is ntext; was declared text).
--   * Transaction + TRY/CATCH; now returns the new Id (previously returned nothing).
CREATE   PROCEDURE dbo.InsertRecreationalWalkGPX
    @RecreationalWalkId int,
    @GPX                nvarchar(max),
    @Notes              nvarchar(max) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NewId int;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.RecreationalWalkGPX
            (RecreationalWalkId, GPX, Notes)
        VALUES
            (@RecreationalWalkId, @GPX, @Notes);

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


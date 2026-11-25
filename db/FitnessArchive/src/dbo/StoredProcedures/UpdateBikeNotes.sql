
-- dbo.UpdateBikeNotes
-- Changes:
--   * @Notes now defaults to NULL (was '').
--   * @Notes was nvarchar(255) writing into a text column (silent truncation at 255, implicit conversion).
--     Now varchar(max).
--   * Raises an error if the bike does not exist; transaction + TRY/CATCH.
CREATE   PROCEDURE dbo.UpdateBikeNotes
    @Id    int,
    @Notes varchar(max) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE dbo.Bike
        SET Notes = @Notes
        WHERE Id = @Id;

        IF @@ROWCOUNT = 0
            THROW 50010, N'Bike not found.', 1;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;

GO


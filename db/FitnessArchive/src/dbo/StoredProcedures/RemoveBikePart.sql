
-- dbo.RemoveBikePart
-- Changes:
--   * @EndDate is `date`; raises an error if the BikePart row does not exist; transaction + TRY/CATCH.
CREATE   PROCEDURE dbo.RemoveBikePart
    @Id      int,
    @EndDate date
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE dbo.BikePart
        SET EndDate = @EndDate
        WHERE Id = @Id;

        IF @@ROWCOUNT = 0
            THROW 50010, N'BikePart not found.', 1;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;

GO


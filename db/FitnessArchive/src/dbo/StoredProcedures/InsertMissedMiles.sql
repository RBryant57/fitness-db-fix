
-- dbo.InsertMissedMiles
-- Changes:
--   * @Notes now defaults to NULL (was '').
--   * BUG: @Miles was `int`, so fractional missed miles were truncated before reaching the decimal(18,2) column.
--   * Explicit column list; @Date `date`; transaction + TRY/CATCH; now returns the new Id.
CREATE   PROCEDURE dbo.InsertMissedMiles
    @Date  date,
    @Miles decimal(18,2),
    @Type  int,
    @Notes nvarchar(max) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NewId int;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.MissedMiles
            ([Date], Miles, ExerciseTypeId, Notes)
        VALUES
            (@Date, @Miles, @Type, @Notes);

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


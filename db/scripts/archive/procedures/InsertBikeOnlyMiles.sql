-- Fixed version of dbo.InsertBikeOnlyMiles (2026-10-14). The pre-fix original is archive/procedures-original/InsertBikeOnlyMiles.sql.
-- Deployed by archive/scripts/00b_apply_procedure_fixes.sql; kept for reference after archiving.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.InsertBikeOnlyMiles
-- Changes:
--   * @Notes now defaults to NULL (was '').
--   * Explicit column list; transaction + TRY/CATCH.
--   * Rejects EndOdometer < StartOdometer (no table constraint enforces it).
--   * @Date is `date`; now returns the new Id (previously returned nothing).
CREATE OR ALTER PROCEDURE dbo.InsertBikeOnlyMiles
    @Date          date,
    @StartOdometer int,
    @EndOdometer   int,
    @BikeId        int,
    @Notes         nvarchar(max) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @EndOdometer < @StartOdometer
        THROW 50002, N'EndOdometer must not be less than StartOdometer.', 1;

    DECLARE @NewId int;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.BikeOnlyMiles
            ([Date], StartOdometer, EndOdometer, BikeId, Notes)
        VALUES
            (@Date, @StartOdometer, @EndOdometer, @BikeId, @Notes);

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

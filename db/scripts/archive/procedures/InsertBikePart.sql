-- Fixed version of dbo.InsertBikePart (2026-10-14). The pre-fix original is archive/procedures-original/InsertBikePart.sql.
-- Deployed by archive/scripts/00b_apply_procedure_fixes.sql; kept for reference after archiving.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.InsertBikePart
-- Changes:
--   * SELECT @@IDENTITY replaced by SCOPE_IDENTITY(), returned as an int column named Id.
--   * @StartDate is `date`; transaction + TRY/CATCH.
CREATE OR ALTER PROCEDURE dbo.InsertBikePart
    @BikeId          int,
    @PartId          int,
    @StartDate       date,
    @OdometerReading int
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NewId int;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.BikePart
            (BikeId, PartId, StartDate, OdometerReading)
        VALUES
            (@BikeId, @PartId, @StartDate, @OdometerReading);

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

-- Fixed version of dbo.InsertBike (2026-10-14). The pre-fix original is archive/procedures-original/InsertBike.sql.
-- Deployed by archive/scripts/00b_apply_procedure_fixes.sql; kept for reference after archiving.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.InsertBike
-- Changes:
--   * @Notes now defaults to NULL (was '').
--   * SELECT @@IDENTITY replaced by SCOPE_IDENTITY(), returned as an int column named Id.
--   * @Name is varchar(50) to match the column (was nvarchar, implicit conversion); @Notes varchar(max) (was ntext into a text column).
--   * @AcquisitionDate is `date`; transaction + TRY/CATCH.
CREATE OR ALTER PROCEDURE dbo.InsertBike
    @Name            varchar(50),
    @ManufacturerId  int,
    @TypeId          int,
    @AcquisitionDate date,
    @BaseMiles       int = 0,
    @Notes           varchar(max) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NewId int;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.Bike
            ([Name], ManufacturerId, TypeId, AcquisitionDate, BaseMiles, Notes)
        VALUES
            (@Name, @ManufacturerId, @TypeId, @AcquisitionDate, @BaseMiles, @Notes);

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

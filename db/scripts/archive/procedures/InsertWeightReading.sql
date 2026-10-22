-- Fixed version of dbo.InsertWeightReading (2026-10-14). The pre-fix original is archive/procedures-original/InsertWeightReading.sql.
-- Deployed by archive/scripts/00b_apply_procedure_fixes.sql; kept for reference after archiving.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.InsertWeightReading
-- Changes:
--   * @Notes now defaults to NULL (was '').
--   * SELECT @@IDENTITY replaced by SCOPE_IDENTITY(), returned as an int column named Id.
--   * @Date `date` (UNIQUE_Date is on this column, so a time portion previously let two readings on one day slip in).
--   * @Notes nvarchar(max); transaction + TRY/CATCH.
CREATE OR ALTER PROCEDURE dbo.InsertWeightReading
    @Date              date,
    @Weight            decimal(4,1),
    @BodyFatPercentage decimal(4,2),
    @Notes             nvarchar(max) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NewId int;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.Weight
            ([Date], [Weight], BodyFatPercentage, Notes)
        VALUES
            (@Date, @Weight, @BodyFatPercentage, @Notes);

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

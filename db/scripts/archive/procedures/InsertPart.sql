-- Fixed version of dbo.InsertPart (2026-10-14). The pre-fix original is archive/procedures-original/InsertPart.sql.
-- Deployed by archive/scripts/00b_apply_procedure_fixes.sql; kept for reference after archiving.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.InsertPart
-- Changes:
--   * @Notes now defaults to NULL (was '').
--   * SELECT @@IDENTITY replaced by SCOPE_IDENTITY(), returned as an int column named Id.
--   * Explicit column list; @Notes varchar(max); transaction + TRY/CATCH.
CREATE OR ALTER PROCEDURE dbo.InsertPart
    @ManufacturerId int,
    @PartTypeId     int,
    @Name           nvarchar(50),
    @Notes          varchar(max) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NewId int;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.Part
            (ManufacturerId, PartTypeId, [Name], Notes)
        VALUES
            (@ManufacturerId, @PartTypeId, @Name, @Notes);

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

-- Fixed version of dbo.UpdatePart (2026-10-14). The pre-fix original is archive/procedures-original/UpdatePart.sql.
-- Deployed by archive/scripts/00b_apply_procedure_fixes.sql; kept for reference after archiving.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.UpdatePart
-- Changes:
--   * @Notes now defaults to NULL (was '').
--   * @Notes was nvarchar(255) writing into a text column (silent truncation at 255). Now varchar(max).
--   * Raises an error if the part does not exist; transaction + TRY/CATCH.
CREATE OR ALTER PROCEDURE dbo.UpdatePart
    @Id             int,
    @ManufacturerId int,
    @PartTypeId     int,
    @Name           nvarchar(50),
    @Notes          varchar(max) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE dbo.Part
        SET ManufacturerId = @ManufacturerId,
            PartTypeId     = @PartTypeId,
            [Name]         = @Name,
            Notes          = @Notes
        WHERE Id = @Id;

        IF @@ROWCOUNT = 0
            THROW 50010, N'Part not found.', 1;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

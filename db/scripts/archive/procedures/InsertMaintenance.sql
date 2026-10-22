-- Fixed version of dbo.InsertMaintenance (2026-10-14). The pre-fix original is archive/procedures-original/InsertMaintenance.sql.
-- Deployed by archive/scripts/00b_apply_procedure_fixes.sql; kept for reference after archiving.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.InsertMaintenance
-- Changes:
--   * @Notes now defaults to NULL (was '').
--   * SELECT @@IDENTITY replaced by SCOPE_IDENTITY(), returned as an int column named Id.
--   * Explicit column list; @Date `date`; @Notes varchar(max); transaction + TRY/CATCH.
CREATE OR ALTER PROCEDURE dbo.InsertMaintenance
    @BikeId      int,
    @PartId      int,
    @ActionTaken nvarchar(50),
    @Date        date,
    @Odometer    int,
    @Notes       varchar(max) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NewId int;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.Maintenance
            (BikeId, PartId, ActionTaken, [Date], Odometer, Notes)
        VALUES
            (@BikeId, @PartId, @ActionTaken, @Date, @Odometer, @Notes);

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

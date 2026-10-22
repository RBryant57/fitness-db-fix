-- Fixed version of dbo.GetPartCount (2026-10-14). The pre-fix original is archive/procedures-original/GetPartCount.sql.
-- Deployed by archive/scripts/00b_apply_procedure_fixes.sql; kept for reference after archiving.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.GetPartCount
-- Changes:
--   * Result column named PartCount; schema-qualified.
CREATE OR ALTER PROCEDURE dbo.GetPartCount
AS
BEGIN
    SET NOCOUNT ON;

    SELECT COUNT(*) AS PartCount
    FROM dbo.Part;
END;
GO


-- dbo.GetPartCount
-- Changes:
--   * Result column named PartCount; schema-qualified.
CREATE   PROCEDURE dbo.GetPartCount
AS
BEGIN
    SET NOCOUNT ON;

    SELECT COUNT(*) AS PartCount
    FROM dbo.Part;
END;

GO


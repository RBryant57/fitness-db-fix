-- Fixed version of dbo.SelectGPXByTypeById (2026-10-14). The pre-fix original is archive/procedures-original/SelectGPXByTypeById.sql.
-- Deployed by archive/scripts/00b_apply_procedure_fixes.sql; kept for reference after archiving.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.SelectGPXByTypeById
-- Changes:
--   * The activity id column now has one name for every type (ActivityId) so callers can read any type the same way.
--   * An unknown @Type raises an error instead of silently returning no result set.
--   * Schema-qualified.
--   Type codes (unchanged): 1 TrainingRide, 2 TrainingRun, 6 RecreationalRide, 7 RecreationalRun,
--                           8 TrainingWalk, 9 RecreationalWalk.
CREATE OR ALTER PROCEDURE dbo.SelectGPXByTypeById
    @Type int,
    @Id   int
AS
BEGIN
    SET NOCOUNT ON;

    IF @Type IS NULL OR @Type NOT IN (1, 2, 6, 7, 8, 9)
        THROW 50006, N'Unknown GPX activity type.', 1;

    IF @Type = 1
        SELECT g.Id, g.TrainingRideId AS ActivityId, g.GPX FROM dbo.TrainingRideGPX AS g WHERE g.TrainingRideId = @Id;
    ELSE IF @Type = 2
        SELECT g.Id, g.TrainingRunId AS ActivityId, g.GPX FROM dbo.TrainingRunGPX AS g WHERE g.TrainingRunId = @Id;
    ELSE IF @Type = 6
        SELECT g.Id, g.RecreationalRideId AS ActivityId, g.GPX FROM dbo.RecreationalRideGPX AS g WHERE g.RecreationalRideId = @Id;
    ELSE IF @Type = 7
        SELECT g.Id, g.RecreationalRunId AS ActivityId, g.GPX FROM dbo.RecreationalRunGPX AS g WHERE g.RecreationalRunId = @Id;
    ELSE IF @Type = 8
        SELECT g.Id, g.TrainingWalkId AS ActivityId, g.GPX FROM dbo.TrainingWalkGPX AS g WHERE g.TrainingWalkId = @Id;
    ELSE
        SELECT g.Id, g.RecreationalWalkId AS ActivityId, g.GPX FROM dbo.RecreationalWalkGPX AS g WHERE g.RecreationalWalkId = @Id;
END;
GO

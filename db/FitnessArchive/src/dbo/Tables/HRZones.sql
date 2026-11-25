CREATE TABLE [dbo].[HRZones] (
    [Id]             INT           NOT NULL,
    [Name]           NVARCHAR (50) NOT NULL,
    [ZoneUpperLimit] INT           NOT NULL,
    [ZoneLowerLimit] INT           NOT NULL,
    CONSTRAINT [PK_HRZones] PRIMARY KEY CLUSTERED ([Id] ASC)
);


GO


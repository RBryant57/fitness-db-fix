CREATE TABLE [dbo].[RecreationalWalkGPX] (
    [Id]                 INT             IDENTITY (1, 1) NOT NULL,
    [RecreationalWalkId] INT             NOT NULL,
    [GPX]                NVARCHAR (MAX)  NOT NULL,
    [Notes]              NVARCHAR (4000) NULL,
    CONSTRAINT [PK_RecreationalWalkGPX] PRIMARY KEY CLUSTERED ([Id] ASC),
    CONSTRAINT [FK_RecreationalWalkGPX_RecreationalWalk] FOREIGN KEY ([RecreationalWalkId]) REFERENCES [dbo].[RecreationalWalk] ([Id])
);


GO


CREATE TABLE [dbo].[RouteDisplay] (
    [Id]          INT             IDENTITY (1, 1) NOT NULL,
    [RouteId]     INT             NOT NULL,
    [Description] NVARCHAR (4000) NOT NULL,
    CONSTRAINT [PK_RouteDescriptionDisplay] PRIMARY KEY CLUSTERED ([Id] ASC),
    CONSTRAINT [FK_RouteDescriptionDisplay_Route] FOREIGN KEY ([RouteId]) REFERENCES [dbo].[Route] ([Id])
);


GO

CREATE UNIQUE NONCLUSTERED INDEX [UNIQUE_RouteId]
    ON [dbo].[RouteDisplay]([RouteId] ASC);


GO


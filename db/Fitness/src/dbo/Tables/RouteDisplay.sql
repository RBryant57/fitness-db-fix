CREATE TABLE [dbo].[RouteDisplay] (
    [Id]          INT             IDENTITY (1, 1) NOT NULL,
    [RouteId]     INT             NOT NULL,
    [Description] NVARCHAR (4000) NOT NULL,
    CONSTRAINT [PK_RouteDisplay] PRIMARY KEY CLUSTERED ([Id] ASC),
    CONSTRAINT [FK_RouteDisplay_Route] FOREIGN KEY ([RouteId]) REFERENCES [dbo].[Route] ([Id])
);


GO

CREATE UNIQUE NONCLUSTERED INDEX [UQ_RouteDisplay_RouteId]
    ON [dbo].[RouteDisplay]([RouteId] ASC);


GO


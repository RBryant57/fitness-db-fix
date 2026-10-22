CREATE TABLE [dbo].[RouteDirection] (
    [Id]                   INT             IDENTITY (1, 1) NOT NULL,
    [RouteId]              INT             NOT NULL,
    [DirectionNumber]      INT             NOT NULL,
    [DirectionMileMarker]  DECIMAL (18, 1) NOT NULL,
    [DirectionDescription] NVARCHAR (MAX)  NOT NULL,
    CONSTRAINT [PK_RouteDirections] PRIMARY KEY CLUSTERED ([Id] ASC),
    CONSTRAINT [FK_RouteDirection_Route] FOREIGN KEY ([RouteId]) REFERENCES [dbo].[Route] ([Id]) ON DELETE CASCADE ON UPDATE CASCADE
);


GO

CREATE UNIQUE NONCLUSTERED INDEX [UNIQUE_Route_Id_Number]
    ON [dbo].[RouteDirection]([RouteId] ASC, [DirectionNumber] ASC) WITH (ALLOW_PAGE_LOCKS = OFF);


GO


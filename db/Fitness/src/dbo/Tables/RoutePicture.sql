CREATE TABLE [dbo].[RoutePicture] (
    [Id]               INT             IDENTITY (1, 1) NOT NULL,
    [RouteId]          INT             NOT NULL,
    [ImageFileName]    NVARCHAR (100)  NOT NULL,
    [ImageDescription] NVARCHAR (4000) NOT NULL,
    CONSTRAINT [PK_RoutePicture] PRIMARY KEY CLUSTERED ([Id] ASC),
    CONSTRAINT [FK_RoutePicture_Route] FOREIGN KEY ([RouteId]) REFERENCES [dbo].[Route] ([Id])
);


GO


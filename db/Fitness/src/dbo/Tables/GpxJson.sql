CREATE TABLE [dbo].[GpxJson] (
    [Id]      INT            IDENTITY (1, 1) NOT NULL,
    [GpsData] NVARCHAR (MAX) NOT NULL,
    CONSTRAINT [PK_GpxJson] PRIMARY KEY CLUSTERED ([Id] ASC)
);


GO


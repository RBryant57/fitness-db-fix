CREATE TABLE [dbo].[BikeOnlyMiles] (
    [Id]            INT             IDENTITY (1, 1) NOT NULL,
    [Date]          DATE            NOT NULL,
    [StartOdometer] INT             NOT NULL,
    [EndOdometer]   INT             NOT NULL,
    [BikeId]        INT             NOT NULL,
    [Notes]         NVARCHAR (4000) NULL,
    CONSTRAINT [PK_BikeOnlyMiles] PRIMARY KEY CLUSTERED ([Id] ASC),
    CONSTRAINT [FK_BikeOnlyMiles_Bike] FOREIGN KEY ([BikeId]) REFERENCES [dbo].[Bike] ([Id])
);


GO

CREATE NONCLUSTERED INDEX [IX_BikeOnlyMiles_BikeId]
    ON [dbo].[BikeOnlyMiles]([BikeId] ASC);


GO

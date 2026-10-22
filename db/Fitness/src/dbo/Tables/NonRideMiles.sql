CREATE TABLE [dbo].[NonRideMiles] (
    [Id]            INT             IDENTITY (1, 1) NOT NULL,
    [Date]          DATE            NOT NULL,
    [StartOdometer] INT             NOT NULL,
    [EndOdometer]   INT             NOT NULL,
    [BikeId]        INT             NOT NULL,
    [Notes]         NVARCHAR (4000) NULL,
    CONSTRAINT [PK_NonBikeMiles] PRIMARY KEY CLUSTERED ([Id] ASC),
    CONSTRAINT [FK_NonRideMiles_Bike] FOREIGN KEY ([BikeId]) REFERENCES [dbo].[Bike] ([Id])
);


GO


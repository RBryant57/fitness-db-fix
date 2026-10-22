CREATE TABLE [dbo].[BikeOnlyMiles] (
    [Id]            INT             IDENTITY (1, 1) NOT NULL,
    [Date]          DATETIME        NOT NULL,
    [StartOdometer] INT             NOT NULL,
    [EndOdometer]   INT             NOT NULL,
    [BikeId]        INT             NOT NULL,
    [Notes]         NVARCHAR (4000) NULL,
    CONSTRAINT [PK__BikeOnlyMiles__4885B9BB] PRIMARY KEY CLUSTERED ([Id] ASC),
    CONSTRAINT [FK_BikeOnlyMiles_Bike] FOREIGN KEY ([BikeId]) REFERENCES [dbo].[Bike] ([Id])
);


GO


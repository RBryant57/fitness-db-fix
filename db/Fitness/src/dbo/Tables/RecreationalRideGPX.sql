CREATE TABLE [dbo].[RecreationalRideGPX] (
    [Id]                 INT             IDENTITY (1, 1) NOT NULL,
    [RecreationalRideId] INT             NOT NULL,
    [GPX]                NVARCHAR (MAX)  NOT NULL,
    [Notes]              NVARCHAR (4000) NULL,
    CONSTRAINT [PK_RecreationalRideGPX] PRIMARY KEY CLUSTERED ([Id] ASC),
    CONSTRAINT [FK_RecreationalRideGPX_RecreationalRide] FOREIGN KEY ([RecreationalRideId]) REFERENCES [dbo].[RecreationalRide] ([Id])
);


GO


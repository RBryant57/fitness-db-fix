CREATE TABLE [dbo].[TrainingRideGPX] (
    [Id]             INT             IDENTITY (1, 1) NOT NULL,
    [TrainingRideId] INT             NOT NULL,
    [GPX]            NVARCHAR (MAX)  NOT NULL,
    [Notes]          NVARCHAR (4000) NULL,
    CONSTRAINT [PK_TrainingRideGPX] PRIMARY KEY CLUSTERED ([Id] ASC),
    CONSTRAINT [FK_TrainingRideGPX_TrainingRide] FOREIGN KEY ([TrainingRideId]) REFERENCES [dbo].[TrainingRide] ([Id])
);


GO


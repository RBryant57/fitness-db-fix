CREATE TABLE [dbo].[BikeHistory] (
    [Id]              INT             NOT NULL,
    [BikeId]          INT             NOT NULL,
    [Frame]           VARCHAR (50)    NOT NULL,
    [Fork]            VARCHAR (50)    NOT NULL,
    [WheelSet]        VARCHAR (50)    NOT NULL,
    [Shifters]        VARCHAR (50)    NOT NULL,
    [Brakes]          VARCHAR (50)    NOT NULL,
    [Cassette]        VARCHAR (50)    NOT NULL,
    [CrankSet]        VARCHAR (50)    NOT NULL,
    [BottomBracket]   VARCHAR (50)    NOT NULL,
    [FrontDerailleur] VARCHAR (50)    NOT NULL,
    [RearDerailleur]  VARCHAR (50)    NOT NULL,
    [Pedals]          VARCHAR (50)    NOT NULL,
    [Headset]         VARCHAR (50)    NOT NULL,
    [Stem]            VARCHAR (50)    NOT NULL,
    [HandleBars]      VARCHAR (50)    NOT NULL,
    [SeatPost]        VARCHAR (50)    NOT NULL,
    [Saddle]          VARCHAR (50)    NOT NULL,
    [Notes]           NVARCHAR (4000) NULL,
    [StartDate]       DATETIME        NOT NULL,
    [EndDate]         DATETIME        NOT NULL,
    CONSTRAINT [PK_BikeHistory] PRIMARY KEY CLUSTERED ([Id] ASC),
    CONSTRAINT [FK_BikeHistory_Bike] FOREIGN KEY ([BikeId]) REFERENCES [dbo].[Bike] ([Id])
);


GO


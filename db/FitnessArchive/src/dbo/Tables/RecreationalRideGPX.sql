CREATE TABLE [dbo].[RecreationalRideGPX] (
    [Id]                 INT             IDENTITY (1, 1) NOT NULL,
    [RecreationalRideId] INT             NOT NULL,
    [GPX]                NVARCHAR (MAX)  NOT NULL,
    [Notes]              NVARCHAR (4000) NULL,
    CONSTRAINT [PK_RecreationalRideGPX] PRIMARY KEY CLUSTERED ([Id] ASC)
);


GO


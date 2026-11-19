CREATE TABLE [dbo].[RouteType] (
    [Id]     INT          IDENTITY (1, 1) NOT NULL,
    [EnumId] INT          NOT NULL,
    [Name]   NVARCHAR (50) NOT NULL,
    CONSTRAINT [PK_RouteType] PRIMARY KEY CLUSTERED ([Id] ASC)
);


GO

CREATE UNIQUE NONCLUSTERED INDEX [UQ_RouteType_EnumId]
    ON [dbo].[RouteType]([EnumId] ASC);


GO


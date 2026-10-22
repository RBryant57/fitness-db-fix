CREATE TABLE [dbo].[Weight] (
    [Id]                INT             IDENTITY (1, 1) NOT NULL,
    [Date]              DATETIME        NOT NULL,
    [Weight]            DECIMAL (4, 1)  NOT NULL,
    [BodyFatPercentage] DECIMAL (4, 2)  NOT NULL,
    [Notes]             NVARCHAR (4000) NULL,
    CONSTRAINT [PK_Weight] PRIMARY KEY CLUSTERED ([Id] ASC)
);


GO

CREATE UNIQUE NONCLUSTERED INDEX [UNIQUE_Date]
    ON [dbo].[Weight]([Date] ASC);


GO


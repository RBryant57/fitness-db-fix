CREATE TABLE [dbo].[PartType] (
    [Id]    INT             IDENTITY (1, 1) NOT NULL,
    [Name]  NVARCHAR (50)   NOT NULL,
    [Notes] NVARCHAR (4000) NULL,
    CONSTRAINT [PK_PartType] PRIMARY KEY CLUSTERED ([Id] ASC),
    CONSTRAINT [CK_PartType_Name] CHECK (NOT [Name] like '')
);


GO

CREATE UNIQUE NONCLUSTERED INDEX [UNIQUE_PartType_Name]
    ON [dbo].[PartType]([Name] ASC);


GO


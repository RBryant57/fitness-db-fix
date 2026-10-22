CREATE TABLE [dbo].[Circuit] (
    [Id]    INT             IDENTITY (1, 1) NOT NULL,
    [Name]  NVARCHAR (100)  NOT NULL,
    [Notes] NVARCHAR (4000) NULL,
    CONSTRAINT [PK_Circuit] PRIMARY KEY CLUSTERED ([Id] ASC)
);


GO

CREATE UNIQUE NONCLUSTERED INDEX [UNIQUE_Name]
    ON [dbo].[Circuit]([Name] ASC);


GO


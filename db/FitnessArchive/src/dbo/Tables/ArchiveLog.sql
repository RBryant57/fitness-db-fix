CREATE TABLE [dbo].[ArchiveLog] (
    [Id]         INT            IDENTITY (1, 1) NOT NULL,
    [ArchivedOn] DATETIME2 (7)  CONSTRAINT [DF__ArchiveLo__Archi__14BBFCF2] DEFAULT (sysutcdatetime()) NOT NULL,
    [Note]       NVARCHAR (400) NOT NULL,
    CONSTRAINT [PK__ArchiveL__3214EC07D916C06E] PRIMARY KEY CLUSTERED ([Id] ASC)
);


GO


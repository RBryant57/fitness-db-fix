CREATE ROLE [FitnessApp]
    AUTHORIZATION [dbo];


GO

GRANT SELECT, INSERT, UPDATE, DELETE
    ON SCHEMA::[dbo] TO [FitnessApp];


GO

GRANT EXECUTE
    ON OBJECT::[dbo].[GetLastEntries] TO [FitnessApp];


GO


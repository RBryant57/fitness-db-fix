-- Placeholder server logins, so the database users in this project can resolve their logins at build time
-- (otherwise: SQL71501 "User ... has an unresolved reference to Login ...").
--
-- These are NEVER deployed: every publish profile must set
--     <ExcludeObjectTypes>Logins</ExcludeObjectTypes>
-- Real logins and their passwords are managed on each server, not in this project.
-- The passwords below are placeholders only and are not the real ones.
--
-- When 04_permissions.sql removes a legacy user, delete its user file and its line here.

CREATE LOGIN [Rick]           WITH PASSWORD = N'placeholder-not-deployed-0!A';
GO
CREATE LOGIN [container_user] WITH PASSWORD = N'placeholder-not-deployed-0!A';
GO
CREATE LOGIN [ElevatedUser]   WITH PASSWORD = N'placeholder-not-deployed-0!A';   -- legacy, removed by 04_permissions
GO
CREATE LOGIN [StandardUser]   WITH PASSWORD = N'placeholder-not-deployed-0!A';   -- legacy, removed by 04_permissions
GO
CREATE LOGIN [FitnessUser]    WITH PASSWORD = N'placeholder-not-deployed-0!A';   -- legacy, removed by 04_permissions
GO
CREATE LOGIN [RouteService]   WITH PASSWORD = N'placeholder-not-deployed-0!A';   -- legacy, removed by 04_permissions
GO

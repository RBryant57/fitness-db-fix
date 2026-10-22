CREATE ROLE [FitnessViewer]
    AUTHORIZATION [dbo];


GO

ALTER ROLE [FitnessViewer] ADD MEMBER [StandardUser];


GO

ALTER ROLE [FitnessViewer] ADD MEMBER [yellowcaddis\sqlservice];


GO

ALTER ROLE [FitnessViewer] ADD MEMBER [FitnessUser];


GO

ALTER ROLE [FitnessViewer] ADD MEMBER [YELLOWCADDIS\commutetrackerservic];


GO

ALTER ROLE [FitnessViewer] ADD MEMBER [RouteService];


GO

ALTER ROLE [FitnessViewer] ADD MEMBER [ElevatedUser];


GO

ALTER ROLE [FitnessViewer] ADD MEMBER [container_user];


GO


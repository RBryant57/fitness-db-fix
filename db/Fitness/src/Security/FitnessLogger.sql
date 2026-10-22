CREATE ROLE [FitnessLogger]
    AUTHORIZATION [dbo];


GO

ALTER ROLE [FitnessLogger] ADD MEMBER [RouteService];


GO

ALTER ROLE [FitnessLogger] ADD MEMBER [ElevatedUser];


GO

ALTER ROLE [FitnessLogger] ADD MEMBER [FitnessUser];


GO

ALTER ROLE [FitnessLogger] ADD MEMBER [container_user];


GO

ALTER ROLE [FitnessLogger] ADD MEMBER [YELLOWCADDIS\commutetrackerservic];


GO

ALTER ROLE [FitnessLogger] ADD MEMBER [yellowcaddis\sqlservice];


GO


DECLARE 
        @AssessDateFrom datetime,
        @AssessDateThru datetime,
        @Organization INT, --required
		@BreakAtOrgLevel INT, --required
		@OrgSet INT --required
        
SET @AssessDateFrom = DATEADD(dd, -365, GETDATE())
SET @AssessDateThru = GETDATE()
SET @Organization = 1
SET @BreakAtOrgLevel = 30
SET @OrgSet = 1

DECLARE @AsssessThruDateTime DATETIME
SET @AsssessThruDateTime =cast((convert(char(10),@AssessDateThru,101) + ' 23:59:59') as datetime)

/*Start OrgBreak Queries - Can be Reused - Builds variable for Org Level Selection Control*/
	DECLARE @OrgLocation TINYINT
	SELECT @OrgLocation = (
		SELECT 
			COUNT(*)
		FROM 
			Organizations (NOLOCK)
		INNER JOIN OrganizationLevels (NOLOCK) ON OrganizationLevels.OrgSet = Organizations.OrgSet
			AND OrganizationLevels.OrgLevel >= Organizations.OrgLevel
		WHERE
			Organizations.OrgSet = @OrgSet
			AND Organizations.OrgEntSys = @Organization)

	DECLARE @BreakAtOrgLevelLocation TINYINT
	SELECT @BreakAtOrgLevelLocation = (
		SELECT 
			COUNT(*)
		FROM 
			OrganizationLevels (NOLOCK)
		WHERE 
			OrganizationLevels.OrgSet = @OrgSet
			AND OrganizationLevels.OrgLevel >= @BreakAtOrgLevel)
/*End OrgBreak Queries - Can be Reused*/



SELECT  DISTINCT
ISNULL(
		(
			CASE	
				WHEN @BreakAtOrgLevelLocation = 1 THEN Organizations.EntSys1
				WHEN @BreakAtOrgLevelLocation = 2 THEN Organizations.EntSys2
				WHEN @BreakAtOrgLevelLocation = 3 THEN Organizations.EntSys3
				WHEN @BreakAtOrgLevelLocation = 4 THEN Organizations.EntSys4
				WHEN @BreakAtOrgLevelLocation = 5 THEN Organizations.EntSys5
				WHEN @BreakAtOrgLevelLocation = 6 THEN Organizations.EntSys6
				WHEN @BreakAtOrgLevelLocation = 7 THEN Organizations.EntSys7
				WHEN @BreakAtOrgLevelLocation = 8 THEN Organizations.EntSys8
				WHEN @BreakAtOrgLevelLocation = 9 THEN Organizations.EntSys9
				WHEN @BreakAtOrgLevelLocation = 10 THEN Organizations.EntSys10
				WHEN @BreakAtOrgLevelLocation = 11 THEN Organizations.EntSys11
				WHEN @BreakAtOrgLevelLocation = 12 THEN Organizations.EntSys12
				WHEN @BreakAtOrgLevelLocation = 13 THEN Organizations.EntSys13
				WHEN @BreakAtOrgLevelLocation = 14 THEN Organizations.EntSys14
				WHEN @BreakAtOrgLevelLocation = 15 THEN Organizations.EntSys15
			END
				),Organizations.OrgEntSys) AS OrgBreak,
				Organizations.FullOrgDesc, 
				SUBSTRING(dbo.AssessTemplate.Description,6,27) as AssessmentName,
				dbo.Entities.DisplayName, 
				dbo.Entities.InternalID AS MRN, 
				dbo.Episodes.AdmissionID, 
				EA.DateCreated,
                EA.EpsAssessSys
FROM         dbo.EpsAssessments EA (NOLOCK) INNER JOIN
                      dbo.Episodes (NOLOCK) ON EA.EpisodeSys = dbo.Episodes.EpisodeSys INNER JOIN
                      dbo.Entities (NOLOCK) ON dbo.Episodes.ResidentSys = dbo.Entities.EntitySys INNER JOIN
                      dbo.EpsAssessDtl (NOLOCK) ON EA.EpsAssessSys = dbo.EpsAssessDtl.EpsAssessSys INNER JOIN
                      dbo.AssessQuestion (NOLOCK) ON dbo.EpsAssessDtl.MDSID = dbo.AssessQuestion.InternalID INNER JOIN
                      dbo.EpsOrganizations (NOLOCK) ON dbo.Episodes.EpisodeSys = dbo.EpsOrganizations.EpisodeSys and EA.DateCreated > dbo.EpsOrganizations.DateActive AND
                      (EA.DateCreated < dbo.EpsOrganizations.DateInactive OR dbo.EpsOrganizations.DateInactive IS NULL)
                      INNER JOIN
                      dbo.Organizations (NOLOCK) ON dbo.EpsOrganizations.OrgEntSys = dbo.Organizations.OrgEntSys
                      INNER JOIN dbo.AssessTemplate (NOLOCK) ON EA.TemplateSys = dbo.assesstemplate.AssessmentSys
WHERE     EA.CompAssessDate IS NULL
and ea.DateCreated < @AsssessThruDateTime
 AND (
			(@OrgLocation IS NULL)
			OR (@OrgLocation=1 AND @Organization = Organizations.EntSys1)
			OR (@OrgLocation=2 AND @Organization = Organizations.EntSys2)
			OR (@OrgLocation=3 AND @Organization = Organizations.EntSys3)
			OR (@OrgLocation=4 AND @Organization = Organizations.EntSys4)
			OR (@OrgLocation=5 AND @Organization = Organizations.EntSys5)
			OR (@OrgLocation=6 AND @Organization = Organizations.EntSys6)
			OR (@OrgLocation=7 AND @Organization = Organizations.EntSys7)
			OR (@OrgLocation=8 AND @Organization = Organizations.EntSys8)
			OR (@OrgLocation=9 AND @Organization = Organizations.EntSys9)
			OR (@OrgLocation=10 AND @Organization = Organizations.EntSys10)
			OR (@OrgLocation=11 AND @Organization = Organizations.EntSys11)
			OR (@OrgLocation=12 AND @Organization = Organizations.EntSys12)
			OR (@OrgLocation=13 AND @Organization = Organizations.EntSys13)
			OR (@OrgLocation=14 AND @Organization = Organizations.EntSys14)
			OR (@OrgLocation=15 AND @Organization = Organizations.EntSys15)
		)
		




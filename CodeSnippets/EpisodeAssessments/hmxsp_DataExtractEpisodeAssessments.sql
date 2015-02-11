IF EXISTS (SELECT 1 FROM sysobjects WHERE xType = 'P' AND name = N'hmxsp_DataExtractEpisodeAssessments')
BEGIN
    DROP PROCEDURE dbo.hmxsp_DataExtractEpisodeAssessments;
END
GO

--Testing Variables
--DECLARE @FacilitySys INT = 697
--DECLARE @AssessmentSysList AS VARCHAR(MAX) = '361,362,363,365,600098,600295,600164,600174,190009'
--DECLARE @BeginEntryDate SMALLDATETIME = '10/1/2014'
--DECLARE @EndEntryDate SMALLDATETIME = '10/31/2014'
--DECLARE @EpisodeSysList VARCHAR(MAX) = '600,610,617,621,31713,31806,33305,33429,33446,33601,33847'
--DECLARE @EpsAssessSysList VARCHAR(MAX) = '7418693,7700672,7725166,7223957,7533802,7534571,7554047,7150642'

--MASTER Episode Assessment Stored Proc

--Parameters are FacilitySys, AssessmentSysList (optional), BeginEntryDate (optional), EndEntryDate (optional), EpisodeSysList (optional), EpsAssessSysList (optional)

--The idea being:
--Scenario 1 – Pure Assessment data dump, only pass in a FacilitySys
--Scenario 2 – All assessments for a given facility of X Type(s), pass in a FacilitySys & AssessmentSysList formatted '361,362,363,365,600098,600295,600164,600174,190009'
--Scenario 3 - All assessments for a given facility of X Type(s) but only between these dates; ), pass in a FacilitySys, AssessmentSysList, BeginEntryDate, EndEntryDate
--Scenario 4 – All Assessments for this Resident Admission, pass in a FacilitySys & EpisodeSysList (all other parameters NULL)
--Scenario 5 – These specific Resident Assessment instances, pass in a FacilitySys & EpsAssessSysList

CREATE PROCEDURE [dbo].[hmxsp_DataExtractEpisodeAssessments]  
 (  
  @FacilitySys AS INT,
  @AssessmentSysList AS VARCHAR(MAX) = NULL,
  @BeginEntryDate AS SMALLDATETIME = NULL,
  @EndEntryDate AS SMALLDATETIME = NULL,
  @EpisodeSysList AS VARCHAR(MAX) = NULL,
  @EpsAssessSysList AS VARCHAR(MAX) = NULL
 ) 
AS  
BEGIN  
 SET NOCOUNT ON;  
	-------------------------------
	--1. Set Variables
	DECLARE @OrgSet INT = dbo.hmxfn_GetOrgSet();  

	IF (@AssessmentSysList IS NULL OR LEN(@AssessmentSysList) = 0)
	BEGIN
		SET @AssessmentSysList = '0'
	END

	IF (@BeginEntryDate IS NULL OR LEN(@BeginEntryDate) = 0)
	BEGIN
	 SET @BeginEntryDate = '1/1/2000'
	END

	IF (@EndEntryDate IS NULL OR LEN(@EndEntryDate) = 0)
	BEGIN
		SET @EndEntryDate = GETDATE()
	END

	IF (@EpisodeSysList IS NULL OR LEN(@EpisodeSysList) = 0)
	BEGIN
		SET @EpisodeSysList = '0'
	END
	
	IF (@EpsAssessSysList IS NULL OR LEN(@EpsAssessSysList) = 0)
	BEGIN
		SET @EpsAssessSysList = '0'
	END

	--2. Make Org aware
	DECLARE @OrgLocation TINYINT
	SELECT @OrgLocation = (
		SELECT COUNT(*)
		FROM Organizations WITH (NOLOCK)
		INNER JOIN OrganizationLevels (NOLOCK) ON OrganizationLevels.OrgSet = Organizations.OrgSet
			AND OrganizationLevels.OrgLevel >= Organizations.OrgLevel
		WHERE Organizations.OrgSet = @OrgSet
			AND Organizations.OrgEntSys = @FacilitySys);

	--3. Create Header Table
	CREATE TABLE #AssessHeader (  
	 EpisodeSys INT NOT NULL,
	 AdmissionID VARCHAR(25) NOT NULL,
	 ResidentSys INT NOT NULL,
	 ResName VARCHAR(100) NOT NULL,
	 EpsAssessSys INT NOT NULL,
	 TemplateSys INT NOT NULL,
	 TemplateDesc VARCHAR(100) NOT NULL,
	 AssessmentType CHAR(2) NOT NULL,
	 AssessmentTypeDesc VARCHAR(100) NOT NULL,
	 CompAssessDate DATETIME NOT NULL,
	 AssessReason VARCHAR(300) NULL,
	 CompUsersys INT NULL,
	 UserName VARCHAR(100) NULL
	);

	--Create index for #AssessHeader table
	CREATE NONCLUSTERED INDEX NTmpAH1 ON #AssessHeader (EpsAssessSys, EpisodeSys);

	--4. Insert INTO Header Table
	INSERT INTO #AssessHeader (EpisodeSys, AdmissionID, ResidentSys, ResName, EpsAssessSys, 
	TemplateSys, TemplateDesc, AssessmentType, AssessmentTypeDesc, 
	CompAssessDate, AssessReason, CompUsersys, UserName) 

	SELECT DISTINCT EA.EpisodeSys, EP.AdmissionID, EA.ResidentSys, EN.DisplayName, EA.EpsAssessSys, 
	EA.TemplateSys, AT.[Description] AS TemplateDesc, AT.AssessmentType, MC.CodeDesc AS AssessmentTypeDesc, 
	EA.CompAssessDate, EA.AssessReason, EA.CompUsersys, Pers.DisplayName
	FROM dbo.EpsAssessments EA with (nolock)
	INNER JOIN dbo.AssessTemplate AT with (nolock) on AT.AssessmentSys = EA.TemplateSys
	INNER JOIN dbo.Episodes EP with (nolock) ON EP.EpisodeSys = EA.EpisodeSys
		AND EP.EpisodeType IN ('AD','OU')
	INNER JOIN dbo.Entities EN with (nolock) ON EN.EntitySys = EA.ResidentSys
	INNER JOIN dbo.EpsOrganizations EO with (nolock) ON EO.EpisodeSys = EA.EpisodeSys
		AND EO.OrgSet = @OrgSet
		AND EO.OrgSeq = (SELECT MAX(OrgSeq) FROM EpsOrganizations EO2
						WHERE EO2.EpisodeSys = EO.EpisodeSys)
		AND EO.DateActive <= @EndEntryDate
		AND (EO.DateInactive >= @BeginEntryDate OR EO.DateInactive IS NULL)
	INNER JOIN dbo.Organizations with (nolock) ON Organizations.OrgEntSys = EO.OrgEntSys
		AND Organizations.OrgSet = @OrgSet
	INNER JOIN dbo.MiscCodes MC with (nolock) ON MC.MiscCode = AT.AssessmentType
		AND MC.MiscCodeType = 'AST'
	INNER JOIN dbo.Personnel P with (nolock) ON P.PersonnelUserSys = EA.CompUsersys
	INNER JOIN dbo.Entities Pers with (nolock) ON Pers.EntitySys = P.PersonnelSys
	WHERE (
				(@OrgLocation IS NULL)
				OR (@OrgLocation=1 AND @FacilitySys = Organizations.EntSys1)
				OR (@OrgLocation=2 AND @FacilitySys = Organizations.EntSys2)
				OR (@OrgLocation=3 AND @FacilitySys = Organizations.EntSys3)
				OR (@OrgLocation=4 AND @FacilitySys = Organizations.EntSys4)
				OR (@OrgLocation=5 AND @FacilitySys = Organizations.EntSys5)
				OR (@OrgLocation=6 AND @FacilitySys = Organizations.EntSys6)
				OR (@OrgLocation=7 AND @FacilitySys = Organizations.EntSys7)
				OR (@OrgLocation=8 AND @FacilitySys = Organizations.EntSys8)
				OR (@OrgLocation=9 AND @FacilitySys = Organizations.EntSys9)
				OR (@OrgLocation=10 AND @FacilitySys = Organizations.EntSys10)
				OR (@OrgLocation=11 AND @FacilitySys = Organizations.EntSys11)
				OR (@OrgLocation=12 AND @FacilitySys = Organizations.EntSys12)
				OR (@OrgLocation=13 AND @FacilitySys = Organizations.EntSys13)
				OR (@OrgLocation=14 AND @FacilitySys = Organizations.EntSys14)
				OR (@OrgLocation=15 AND @FacilitySys = Organizations.EntSys15)
		)
	--5. Check Optional Variables	
		AND ('0' IN (@EpsAssessSysList) OR EA.EpsAssessSys IN (SELECT [Value] FROM dbo.SplitMax(@EpsAssessSysList, ',')))
		AND ('0' IN (@EpisodeSysList) OR EA.EpisodeSys IN (SELECT [Value] FROM dbo.SplitMax(@EpisodeSysList, ',')))
		AND ('0' IN (@AssessmentSysList) OR EA.TemplateSys IN (SELECT [Value] FROM dbo.SplitMax(@AssessmentSysList, ',')))
		AND EA.CompAssessDate BETWEEN @BeginEntryDate AND @EndEntryDate;

	--select * from #AssessHeader

	--6. Create Question/Answer Table
	CREATE TABLE #AssessAnswers (  
	 EpsAssessSys INT NOT NULL,
	 DtlSeq INT NOT NULL,
	 QuestionSys INT NOT NULL,
	 QuestionText VARCHAR(MAX) NOT NULL,
	 AnswerResponseType CHAR(2) NOT NULL,  
	 AnswerValue VARCHAR(MAX) NULL,  
	 AnswerText VARCHAR(MAX) NULL
	 );
	  
	--Create index for #AssessAnswers table
	CREATE NONCLUSTERED INDEX NTmpAA1 ON #AssessAnswers (EpsAssessSys, DtlSeq, QuestionSys);

	--7. Insert INTO Question/Answer Table from vwEpsAssessDtl
	INSERT INTO #AssessAnswers (EpsAssessSys, DtlSeq, QuestionSys, QuestionText, AnswerResponseType, AnswerValue)--, AnswerText)
	SELECT AH.EpsAssessSys, EAD.DtlSeq, AQ.QuestionSys, AQ.[Text],
	AQ.AnswerResponseType, EAD.[Value] --, AA.[Description]
	FROM #AssessHeader AH WITH (NOLOCK)
	INNER JOIN dbo.vwEpsAssessDtl EAD WITH (NOLOCK) ON AH.EpsAssessSys = EAD.EpsAssessSys
	INNER JOIN dbo.AssessTempDtl ATD WITH (NOLOCK) ON ATD.AssessmentSys = AH.TemplateSys
		AND ATD.TempDtlSeq = EAD.DtlSeq
		AND ATD.DtlType = 'QU'
	INNER JOIN dbo.AssessQuestion AQ WITH (NOLOCK) ON AQ.QuestionSys = ATD.DtlSys
	
	--Physical Monitors
	INSERT INTO #AssessAnswers (EpsAssessSys, DtlSeq, QuestionSys, QuestionText, AnswerResponseType, AnswerValue)--, AnswerText)	
	SELECT AH.EpsAssessSys, PMC.DtlSeq, '0', MC.CodeDesc,
	'PM', PMC.[Value]--, AA.[Description]
	FROM #AssessHeader AH WITH (NOLOCK)
	INNER JOIN dbo.PhysMonCapture PMC WITH (NOLOCK) ON AH.EpsAssessSys = PMC.EpsAssessSys
	INNER JOIN dbo.AssessTempDtl ATD WITH (NOLOCK) ON ATD.AssessmentSys = AH.TemplateSys
		AND ATD.TempDtlSeq = PMC.DtlSeq
		AND ATD.DtlType = 'PM'
	INNER JOIN dbo.MiscCodes MC WITH (NOLOCK) ON MC.MCSys = ATD.PhysMonMCSys;

	--select * from #AssessAnswers

	--8. Reformat some Questions/Answers
	UPDATE AA
	SET AnswerText = AA.AnswerValue
	FROM #AssessAnswers AA
	WHERE AnswerResponseType = 'PM'
		AND AA.AnswerText IS NULL
		AND AA.AnswerValue IS NOT NULL
	
	--Answer is Personnel/EntitySys, need Entity Name
	--AnswerResponseType IN AP,EN,PD,PR,PS,RP,RS,SI
	UPDATE AA
	SET AnswerText = E.DisplayName
	FROM #AssessAnswers AA
	INNER JOIN dbo.Entities E with (nolock) ON E.EntitySys = Cast(AA.AnswerValue AS INT)
	WHERE AnswerResponseType IN ('AP','EN','PD','PR','PS','RP','RS','SI')
		AND AA.AnswerValue LIKE '[^a-zA-Z]%'
		AND AA.AnswerText IS NULL
		AND AA.AnswerValue IS NOT NULL;

	--All the Other Personnel/EntitySys Type Answers (AssessAnswer.Value already is name)
	--AnswerResponseType IN AP,EN,PD,PR,PS,RP,RS,SI
	UPDATE AA
	SET AnswerText = AA.AnswerValue
	FROM #AssessAnswers AA
	WHERE AnswerResponseType IN ('AP','EN','PD','PR','PS','RP','RS','SI')
		AND AA.AnswerText IS NULL
		AND AA.AnswerValue IS NOT NULL;

	--Answer is Primary PlanSys / Funding Coverage, Need PlanDesc
	--AnswerResponseType IN AI,FC
	UPDATE AA
	SET AnswerText = P.PlanID
	FROM #AssessAnswers AA
	INNER JOIN dbo.Plans P with (nolock) ON P.PlanSys = Cast(AA.AnswerValue AS INT)
	WHERE AnswerResponseType IN ('AI','FC')
		AND AA.AnswerText IS NULL
		AND AA.AnswerValue IS NOT NULL;
		
	--Answer is Allergy 1, Need AllergyID Text
	--AnswerResponseType=AS
	UPDATE AA
	SET AnswerText = A.AllergyID
	FROM #AssessAnswers AA
	INNER JOIN dbo.Allergies A with (nolock) ON A.AllergySys = Cast(AA.AnswerValue AS INT)
	WHERE AnswerResponseType = 'AS'
		AND AA.AnswerText IS NULL
		AND AA.AnswerValue IS NOT NULL;
		
	--Answer is ResMeds, Need OrderText
	--AnswerResponseType=MA
	UPDATE AA
	SET AnswerText = RM.OrderText
	FROM #AssessAnswers AA
	INNER JOIN dbo.ResMeds RM with (nolock) ON RM.MedAdminSys = Cast(AA.AnswerValue AS INT)
	WHERE AnswerResponseType = 'MA'
		AND AA.AnswerText IS NULL
		AND AA.AnswerValue IS NOT NULL;
		
	--AnswerResponseType=MS
	--Answer Formatted like 36973~|~1
	UPDATE AA
	SET AnswerText = RM.OrderText
	FROM #AssessAnswers AA
	INNER JOIN dbo.ResMeds RM with (nolock) ON RM.MedSys = CAST(LEFT(AA.AnswerValue,CHARINDEX('~',AA.AnswerValue)- 1) AS INT)
	WHERE AnswerResponseType = 'MS'
		AND AA.AnswerText IS NULL
		AND AA.AnswerValue IS NOT NULL;

	--Answer is Single Answer as pulled from AssessAnswer.AnswerSys
	--AnswerResponseType IN CO,YN
	UPDATE AA
	SET AnswerText = ASA.[Description]
	FROM #AssessAnswers AA
	INNER JOIN dbo.AssessAnswer ASA WITH (NOLOCK) ON ASA.QuestionSys = AA.QuestionSys
	WHERE AnswerResponseType IN ('CO','YN')
		AND AA.AnswerText IS NULL
		AND AA.AnswerValue = ASA.AnswerSys;

	--Convert Single Answers from AnswerValue to AnswerTexts that are still blank
	--AnswerResponseType IN DL,DT,FI,IA,IC,IP,IR,IT,MC,PH,RO,SC,SD,SN,SV,SU,RV,WR
	UPDATE AA
	SET AnswerText = AA.AnswerValue
	FROM #AssessAnswers AA
	WHERE AnswerResponseType IN ('DL','DT','FI','IA','IC','IP','IR','IT','MC','PH','RO','SC','SD','SN','SV','SU','RV','WR')
		AND AA.AnswerText IS NULL
		AND AA.AnswerValue IS NOT NULL;

	--9. Create Final Merged Res Assessment Table
	CREATE TABLE #AssessMaster (  
	 EpisodeSys INT,
	 AdmissionID VARCHAR(25),
	 ResidentSys INT,
	 ResName VARCHAR(100),
	 EpsAssessSys INT,
	 TemplateSys INT,
	 TemplateDesc VARCHAR(100),
	 AssessmentType CHAR(2),
	 AssessmentTypeDesc VARCHAR(100),
	 CompAssessDate DATETIME,
	 AssessReason VARCHAR(300),
	 CompUsersys INT,
	 UserName VARCHAR(100),
	 DtlSeq INT,
	 QuestionSys INT,
	 QuestionText VARCHAR(MAX),
	 AnswerResponseType CHAR(2),  
	 AnswerValue VARCHAR(MAX),  
	 AnswerText VARCHAR(MAX)
	);
	
	--Create index for #AssessMaster table
	CREATE NONCLUSTERED INDEX NTmpAM1 ON #AssessAnswers (EpsAssessSys, DtlSeq, QuestionSys);

	--10. Insert INTO Final Merged Res Assessment Table
	INSERT INTO #AssessMaster (EpisodeSys, AdmissionID, ResidentSys, ResName, 
		EpsAssessSys, TemplateSys, TemplateDesc, AssessmentType, AssessmentTypeDesc,
		CompAssessDate, AssessReason, CompUsersys, UserName,
		DtlSeq, QuestionSys, QuestionText, AnswerResponseType, AnswerValue, AnswerText)

	SELECT AH.EpisodeSys, AH.AdmissionID, AH.ResidentSys, AH.ResName, 
		AH.EpsAssessSys, AH.TemplateSys, AH.TemplateDesc, AH.AssessmentType, AH.AssessmentTypeDesc,
		AH.CompAssessDate, AH.AssessReason, AH.CompUsersys, AH.UserName,
		AA.DtlSeq, AA.QuestionSys, AA.QuestionText, AA.AnswerResponseType, AA.AnswerValue, 
		CASE WHEN AA.AnswerResponseType IN ('CK','CM','MD') THEN ASA.[Description] 
			WHEN TI.InterventionDesc = 'TI' THEN TI.InterventionDesc
			ELSE AA.AnswerText 
		END
	FROM #AssessHeader AH WITH (NOLOCK)
	INNER JOIN #AssessAnswers AA WITH (NOLOCK) ON AA.EpsAssessSys = AH.EpsAssessSys
	LEFT JOIN dbo.AssessAnswer ASA WITH (NOLOCK) ON ASA.QuestionSys = AA.QuestionSys
		AND AA.AnswerResponseType IN ('CK','CM','MD') --Comma separated EpsAssessDtl.AnswersSys AnswerResponseTypes
		AND ((',' + RTRIM(AA.AnswerValue) + ',' like '%,' + CAST(ASA.AnswerSys AS VARCHAR(max)) + ',%')) --To handle multiple AnswerValues like 1,3,5,9
	LEFT JOIN dbo.TherapyIntervention TI WITH (NOLOCK) ON (',' + RTRIM(AA.AnswerValue) + ',' like '%,' + CAST(TI.InterventionSys AS VARCHAR(max)) + ',%')
		AND AA.AnswerResponseType = 'TI'; --To handle multiple AnswerValues like 1,3,5,9 that are TherapyInterventions

	--11. Final Res Assessment select
	SELECT ResName, ResidentSys, EpisodeSys, AdmissionID,  
		EpsAssessSys, TemplateSys, TemplateDesc, AssessmentType, AssessmentTypeDesc,
		CompAssessDate, AssessReason, CompUsersys, UserName,
		DtlSeq, QuestionSys, QuestionText, AnswerResponseType, AnswerValue, AnswerText 
	FROM #AssessMaster
	ORDER BY Episodesys, EpsAssessSys, QuestionSys

	--12. Drop Temp tables
	drop table #AssessHeader;
	drop table #AssessAnswers;
	drop table #AssessMaster;

 SET NOCOUNT OFF;  
END;
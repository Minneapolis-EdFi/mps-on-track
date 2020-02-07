/****	RunGradComputation	***/
IF OBJECT_ID('gradCredits.LoadGrades', 'P') IS NOT NULL
    DROP PROCEDURE gradCredits.LoadGrades
GO

CREATE PROCEDURE gradCredits.LoadGrades
		@destinationDb NVARCHAR(100) NULL,
		@sourceDb NVARCHAR(100) NULL
AS

SET NOCOUNT ON;


IF @destinationDb IS NULL 
	SET @destinationDb = 'OnTrackDB'
IF @sourceDb IS NULL
	SET @sourceDb = 'EdFi_Ods_Mnpls_Template'


DECLARE
	@ProcName NVARCHAR(100) = 'LoadGrades',
	@ExecStart DATETIME = GETDATE(),
	@ExecutionLogId INT,
	@GradRequirementSchoolLogDetailId INT,
	@GradRequirementSchoolYearLogDetailId INT,
	@GradRequirementGradeLevelLogDetailId INT,
	@GradRequirementGradingPeriodLogDetailId INT,
	@GradRequirementStudentLogDetailId INT,
	@GradRequirementSSALogDetailId INT,
	@GradRequirementStudentGradeLogDetailId INT,
	@ErrorMessage NVARCHAR(MAX),
	@RecordsAuditedCount INT = 0,
	@SQL NVARCHAR(MAX)

EXEC gradCredits.GetExecutionLogId @ProcName, @ExecStart, @ExecutionLogId OUTPUT


IF OBJECT_ID('tempdb.dbo.#StudentData', 'U') IS NOT NULL
	DROP TABLE #StudentData;

CREATE TABLE #StudentData (
	StudentUSI INT,
	StudentChartId INT,
	StudentDistrictId INT,
	StudentName NVARCHAR(255),
	StudentUniqueId INT,
	GraduationSchoolId INT
)

SET @SQL = 
	CONCAT('
	INSERT INTO #StudentData
	SELECT s.StudentUSI, 
		StudentChartId.IdentificationCode StudentChartId, 
		StudentDistrictId.IdentificationCode StudentDistrictId,
		CONCAT(s.FirstName, '' '',IIF(NULLIF(LTRIM(RTRIM(s.MiddleName)),'''') IS NULL,'''',CONCAT(s.MiddleName, '' '')),s.LastSurname) StudentName, 
		s.StudentUniqueId,
		GraduationSchoolId	
	FROM ' , @sourceDb , '.edfi.Student s WITH (NOLOCK)
	INNER JOIN
		(SELECT StudentUSI, IdentificationCode
		FROM ' , @sourceDb , '.edfi.StudentIdentificationCode sic  WITH (NOLOCK)
		INNER JOIN ' , @sourceDb , '.edfi.StudentIdentificationSystemDescriptor sis 
			ON sic.StudentIdentificationSystemDescriptorId = sis.StudentIdentificationSystemDescriptorId
		INNER JOIN ' , @sourceDb , '.edfi.Descriptor d on sis.StudentIdentificationSystemDescriptorId = d.DescriptorId
		WHERE CodeValue = ''District'') StudentDistrictId
		ON s.StudentUSI = StudentDistrictId.StudentUSI
	INNER JOIN
		(SELECT StudentUSI, IdentificationCode
		FROM ' , @sourceDb , '.edfi.StudentIdentificationCode sic  WITH (NOLOCK)
		INNER JOIN ' , @sourceDb , '.edfi.StudentIdentificationSystemDescriptor sis 
			ON sic.StudentIdentificationSystemDescriptorId = sis.StudentIdentificationSystemDescriptorId
		INNER JOIN ' , @sourceDb , '.edfi.Descriptor d on sis.StudentIdentificationSystemDescriptorId = d.DescriptorId
		WHERE CodeValue = ''Other'') StudentChartId
		ON s.StudentUSI = StudentChartId.StudentUSI
	LEFT JOIN 
		(SELECT seo.StudentUSI, seo.EducationOrganizationId  as GraduationSchoolId
		FROM ' , @sourceDb , '.edfi.StudentEducationOrganizationAssociation seo WITH (NOLOCK)
		INNER JOIN ' , @sourceDb , '.edfi.ResponsibilityDescriptor rd 
			on seo.ResponsibilityDescriptorId = seo.ResponsibilityDescriptorId
		INNER JOIN ' , @sourceDb , '.edfi.Descriptor d on rd.ResponsibilityDescriptorId = d.DescriptorId
		WHERE CodeValue = ''Graduation'') GradSchool
		ON s.StudentUSI = GradSchool.StudentUSI')

EXEC(@SQL)

CREATE NONCLUSTERED INDEX IX_NCI_STD_CUMMGRARES 
ON #StudentData(StudentUSI, StudentName, StudentChartId, StudentDistrictId, StudentUniqueId)


IF OBJECT_ID('tempdb.dbo.#CurrentGradesDataWithEarnedCredits', 'U') IS NOT NULL
	DROP TABLE #CurrentGradesDataWithEarnedCredits;


CREATE TABLE #CurrentGradesDataWithEarnedCredits (
	StudentUSI INT,
	StudentChartId INT,
	StudentDistrictId INT,
	StudentName NVARCHAR(255),
	StudentUniqueId INT,
	GraduationSchoolId INT,
	SchoolYearWhenTaken SMALLINT,
	CurrentGradeLevel VARCHAR(25),
	GradeLevelWhenTaken VARCHAR(25),
	CourseSchoolId INT,
	LetterGradeEarned VARCHAR(5),
	GradingPeriod VARCHAR(25),
	Term VARCHAR(25),
	CourseCode VARCHAR(25),
	CourseTitle VARCHAR(255),
	CourseSchoolName VARCHAR(255),
	GradeSource VARCHAR(25),
	TermDescriptorId INT,
	EarnedCredits DECIMAL(6,3),
	Status VARCHAR(25)
)

SET @SQL = 
	CONCAT('
	INSERT INTO #CurrentGradesDataWithEarnedCredits
	SELECT cg.*, ct.EarnedCredits, car.CodeValue AS Status	
	FROM 
	(
		SELECT s.*, 
			g.SchoolYear as SchoolYearWhenTaken, 
			glt.CodeValue as CurrentGradeLevel, 
			glt.CodeValue as GradeLevelWhenTaken, 
			g.SchoolId as CourseSchoolId,
			g.LetterGradeEarned, 
			dp.CodeValue as GradingPeriod, 
			te.CodeValue as Term, 
			g.LocalCourseCode as CourseCode, 
			c.CourseTitle, 
			eo.NameOfInstitution as CourseSchoolName, 
			''Grades'' as GradeSource,
			td.TermDescriptorId
		FROM ' , @sourceDb ,'.edfi.Grade g WITH (NOLOCK)
		INNER JOIN ' , @sourceDb , '.edfi.Course c  WITH (NOLOCK) ON g.LocalCourseCode = c.CourseCode and g.SchoolId = c.EducationOrganizationId
		INNER JOIN #StudentData s  WITH (NOLOCK) ON g.StudentUSI = s.StudentUSI
		INNER JOIN ' , @sourceDb , '.edfi.GradeType gt WITH (NOLOCK) on g.GradeTypeId = gt.GradeTypeId
		INNER JOIN ' , @sourceDb , '.edfi.EducationOrganization eo WITH (NOLOCK) ON g.SchoolId = eo.EducationOrganizationId
		LEFT JOIN ' , @sourceDb , '.edfi.CurrentStudentSchoolAssociation ssa WITH (NOLOCK) ON g.StudentUSI = ssa.StudentUSI AND g.SchoolId = ssa.SchoolId 
		LEFT JOIN ' , @sourceDb , '.edfi.Descriptor de WITH (NOLOCK) ON ssa.EntryGradeLevelDescriptorId = de.DescriptorId
		LEFT JOIN ' , @sourceDb , '.edfi.GradeLevelDescriptor gld WITH (NOLOCK) ON de.DescriptorId = gld.GradeLevelDescriptorId
		LEFT JOIN ' , @sourceDb , '.edfi.GradeLevelType glt WITH (NOLOCK) ON gld.GradeLevelTypeId = glt.GradeLevelTypeId
		LEFT JOIN ' , @sourceDb , '.edfi.Descriptor te WITH (NOLOCK) ON te.DescriptorId = g.TermDescriptorId
		LEFT JOIN ' , @sourceDb , '.edfi.TermDescriptor td WITH (NOLOCK) ON te.DescriptorId = td.TermDescriptorId
		LEFT JOIN ' , @sourceDb , '.edfi.Descriptor dp WITH (NOLOCK) on g.GradingPeriodDescriptorId = dp.DescriptorId
		WHERE glt.CodeValue in (''Ninth grade'', ''Tenth grade'', ''Eleventh grade'', ''Twelfth grade'') 
	) cg
	LEFT JOIN ' , @sourceDb , '.edfi.CourseTranscript ct WITH (NOLOCK) ON cg.StudentUSI = ct.StudentUSI AND cg.SchoolYearWhenTaken = ct.SchoolYear 
		AND cg.TermDescriptorId = ct.TermDescriptorId AND cg.CourseCode = ct.CourseCode AND cg.CourseSchoolId = ct.CourseEducationOrganizationId
	LEFT JOIN ' , @sourceDb , '.edfi.CourseAttemptResultType car WITH (NOLOCK) ON ct.CourseAttemptResultTypeId = car.CourseAttemptResultTypeId')	 



EXEC(@SQL)


CREATE CLUSTERED INDEX IX_NCI_STD_CRRGRADES 
ON #CurrentGradesDataWithEarnedCredits(StudentUSI, Term, CourseCode, SchoolYearWhenTaken, CourseSchoolId, GradeLevelWhenTaken)


IF OBJECT_ID('tempdb.dbo.#CourseTranscriptGradesDataOnly', 'U') IS NOT NULL
	DROP TABLE #CourseTranscriptGradesDataOnly;


CREATE TABLE #CourseTranscriptGradesDataOnly (
	StudentUSI INT,
	StudentChartId INT,
	StudentDistrictId INT,
	StudentName NVARCHAR(255),
	StudentUniqueId INT,
	GraduationSchoolId INT,
	SchoolYearWhenTaken SMALLINT,
	GradeLevelWhenTaken VARCHAR(25),
	CourseSchoolId INT,
	CourseCode VARCHAR(25),
	CourseTitle VARCHAR(255),
	Term VARCHAR(25),
	EarnedCredits DECIMAL(6,3),
	Status VARCHAR(25),
	LetterGradeEarned VARCHAR(5),
	GradingPeriod VARCHAR(25),
	CurrentGradeLevel VARCHAR(25),
	CourseSchoolName VARCHAR(255),
	GradeSource VARCHAR(25)
)


SET @SQL = 
	CONCAT('
	INSERT INTO #CourseTranscriptGradesDataOnly
	SELECT * 
	FROM 
		(
			SELECT s.*, 
				ct.SchoolYear as SchoolYearWhenTaken, 
				gllt.CodeValue as GradeLevelWhenTaken, 
				ct.CourseEducationOrganizationId as CourseSchoolId,
				ct.CourseCode, 
				ct.CourseTitle, 
				te.CodeValue as Term, 
				ct.EarnedCredits, 
				car.CodeValue as Status, 
				FinalLetterGradeEarned LetterGradeEarned ,
				NULL as GradingPeriod, 
				NULL as CurrentGradeLevel, 
				eo.NameOfInstitution as CourseSchoolName, 
				''CourseTranscript'' as GradeSource		
		FROM ', @sourceDb , '.edfi.CourseTranscript ct WITH (NOLOCK)
		INNER JOIN #StudentData s ON ct.StudentUSI = s.StudentUSI		
		INNER JOIN ' , @sourceDb , '.edfi.EducationOrganization eo WITH (NOLOCK) ON ct.CourseEducationOrganizationId = eo.EducationOrganizationId
		LEFT JOIN ' , @sourceDb , '.edfi.CourseAttemptResultType car WITH (NOLOCK) ON ct.CourseAttemptResultTypeId = car.CourseAttemptResultTypeId	
		LEFT JOIN ' , @sourceDb , '.edfi.Descriptor dde WITH (NOLOCK) ON ct.WhenTakenGradeLevelDescriptorId = dde.DescriptorId
		LEFT JOIN ' , @sourceDb , '.edfi.GradeLevelDescriptor ggld WITH (NOLOCK) ON dde.DescriptorId = ggld.GradeLevelDescriptorId
		LEFT JOIN ' , @sourceDb , '.edfi.GradeLevelType gllt WITH (NOLOCK) ON ggld.GradeLevelTypeId = gllt.GradeLevelTypeId
		LEFT JOIN ' , @sourceDb , '.edfi.Descriptor te WITH (NOLOCK) ON te.DescriptorId = ct.TermDescriptorId
		LEFT JOIN ' , @sourceDb , '.edfi.TermDescriptor td WITH (NOLOCK) ON te.DescriptorId = td.TermDescriptorId
		WHERE gllt.CodeValue in (''Ninth grade'', ''Tenth grade'', ''Eleventh grade'', ''Twelfth grade'') 
			or (gllt.CodeValue in ( ''Seventh grade'', ''Eighth grade'', ''Sixth grade'',
									''Ninth grade'', ''Tenth grade'', ''Eleventh grade'', ''Twelfth grade'') 
			and (ct.CourseCode in	(''04201'',''04201q2'',''04201q3'',''04201q4'',       
								''048110'',''048110q2'',''048110q3'',''048110q4'',
								''041110'',''041110q2'',''041110q3'',''041110q4'',
								''042011'',''042011q2'',''042011q3'',''042011q4'', 
								''048401'',''048401q2'',''048401q3'',''048401q4'', 
								''04888M'',''04888Mq2'',''04888Mq3'',''04888Mq4'')))
		) cte
		WHERE NOT EXISTS
		(
			SELECT 1 FROM #CurrentGradesDataWithEarnedCredits cg
			WHERE cg.StudentUSI = cte.StudentUSI 
			AND cg.Term = cte.Term 
			AND cg.CourseCode = cte.CourseCode
			AND cg.SchoolYearWhenTaken = cte.SchoolYearWhenTaken
			AND cg.CourseSchoolId = cte.CourseSchoolId
			AND cg.GradeLevelWhenTaken = cte.GradeLevelWhenTaken
		)')



EXEC(@SQL)

	
CREATE CLUSTERED INDEX IX_NCI_STD_CRRGRDATA 
ON #CourseTranscriptGradesDataOnly(StudentUSI)



IF OBJECT_ID('tempdb.dbo.#CummulativeGrades', 'U') IS NOT NULL
	DROP TABLE #CummulativeGrades;

SELECT *
INTO #CummulativeGrades
FROM
	(
		SELECT StudentUSI, StudentChartId, StudentDistrictId, StudentUniqueId, GraduationSchoolId, StudentName, CourseSchoolId, CourseSchoolName,
			SchoolYearWhenTaken, GradingPeriod, CurrentGradeLevel, GradeLevelWhenTaken, CourseCode, CourseTitle, Term, GradeSource, LetterGradeEarned,
			CASE WHEN EarnedCredits IS NOT NULL THEN EarnedCredits
				WHEN EarnedCredits IS NULL AND LetterGradeEarned NOT IN ('F','NC','INC') THEN 0.25
				ELSE 0.00 END as EarnedCredits,
			CASE WHEN Status IS NOT NULL THEN Status
				WHEN Status IS NULL AND LetterGradeEarned = 'F' THEN 'Fail'
				WHEN Status IS NULL AND LetterGradeEarned IN ('NC','INC') THEN 'Incomplete'
				ELSE 'Pass' END as Status	
		FROM #CurrentGradesDataWithEarnedCredits 
		UNION ALL
		SELECT StudentUSI, StudentChartId, StudentDistrictId, StudentUniqueId, GraduationSchoolId, StudentName,  CourseSchoolId, CourseSchoolName,
			SchoolYearWhenTaken, GradingPeriod, CurrentGradeLevel, GradeLevelWhenTaken, CourseCode, CourseTitle, Term, GradeSource, LetterGradeEarned, 
			EarnedCredits, Status 
		FROM #CourseTranscriptGradesDataOnly 
	) a



CREATE CLUSTERED INDEX IX_NCI_STD_CUMGRADST 
ON #CummulativeGrades(StudentUSI, SchoolYearWhenTaken, GradeLevelWhenTaken)



IF OBJECT_ID('tempdb.dbo.#StudentGrades', 'U') IS NOT NULL
	DROP TABLE #StudentGrades;



CREATE TABLE #StudentGrades (
	StudentUSI INT,
	StudentChartId INT,
	StudentDistrictId INT,
	StudentUniqueId INT,
	GraduationSchoolId INT,
	StudentName NVARCHAR(255),
	CourseSchoolId INT,
	CourseSchoolName VARCHAR(255),
	SchoolYearWhenTaken SMALLINT,
	GradingPeriod VARCHAR(25),
	CurrentGradeLevel VARCHAR(25),
	GradeLevelWhenTaken VARCHAR(25),
	CourseCode VARCHAR(25),
	CourseTitle VARCHAR(255),
	Term VARCHAR(25),
	GradeSource VARCHAR(25),
	LetterGradeEarned VARCHAR(5),
	EarnedCredits DECIMAL(6,3),
	Status VARCHAR(25)
)

SET @SQL = CONCAT('
		INSERT INTO #StudentGrades
		SELECT *
		FROM #CummulativeGrades cg
		WHERE StudentUSI IN 
			(
				SELECT DISTINCT StudentUSI 
				FROM #CummulativeGrades 
				WHERE SchoolYearWhenTaken = (SELECT SchoolYear FROM ' , @sourceDb , '.edfi.SchoolYearType WHERE CurrentSchoolYear = 1)
				AND GradeLevelWhenTaken in (''Ninth grade'',''Tenth grade'',''Eleventh grade'',''Twelfth grade'')
			)')


EXEC (@SQL)


CREATE CLUSTERED INDEX IX_CI_STD_CUMMGRES 
ON #StudentGrades(StudentUSI, StudentUniqueId, GradingPeriod, SchoolYearWhenTaken, GradeLevelWhenTaken)


CREATE TABLE #GradRequirementSchoolMerge (MERGE_ACTION VARCHAR(20));
CREATE TABLE #GradRequirementSchoolYearMerge (MERGE_ACTION VARCHAR(20));
CREATE TABLE #GradRequirementGradeLevelMerge (MERGE_ACTION VARCHAR(20));
CREATE TABLE #GradRequirementGradingPeriodMerge (MERGE_ACTION VARCHAR(20));
CREATE TABLE #GradRequirementStudentMerge (MERGE_ACTION VARCHAR(20));
CREATE TABLE #GradRequirementSSAMerge (MERGE_ACTION VARCHAR(20));
CREATE TABLE #GradRequirementStudentGradeMerge (MERGE_ACTION VARCHAR(20));

EXEC gradCredits.GetExecutionLogDetailId 'GradRequirementSchool', @ExecutionLogId, @GradRequirementSchoolLogDetailId OUTPUT
EXEC gradCredits.GetExecutionLogDetailId 'GradRequirementSchoolYear', @ExecutionLogId, @GradRequirementSchoolYearLogDetailId OUTPUT
EXEC gradCredits.GetExecutionLogDetailId 'GradRequirementGradeLevel', @ExecutionLogId, @GradRequirementGradeLevelLogDetailId OUTPUT
EXEC gradCredits.GetExecutionLogDetailId 'GradRequirementGradingPeriod', @ExecutionLogId, @GradRequirementGradingPeriodLogDetailId OUTPUT
EXEC gradCredits.GetExecutionLogDetailId 'GradRequirementStudent', @ExecutionLogId, @GradRequirementStudentLogDetailId OUTPUT
EXEC gradCredits.GetExecutionLogDetailId 'GradRequirementStudentSchoolAssociation', @ExecutionLogId, @GradRequirementSSALogDetailId OUTPUT
EXEC gradCredits.GetExecutionLogDetailId 'GradRequirementStudentGrade', @ExecutionLogId, @GradRequirementStudentGradeLogDetailId OUTPUT


	BEGIN TRY	
		/**	GradRequirementSchool	**/
		DECLARE @GRSQuery NVARCHAR(MAX) = 
			'MERGE INTO ' + @destinationDb + '.gradCredits.GradRequirementSchool AS TARGET
			USING (SELECT LocalEducationAgencyId SchoolId, ''DISTRICT'' SchoolName
					FROM ' + @sourceDb + '.edfi.LocalEducationAgency

					UNION

					SELECT GraduationSchoolId, NameOfInstitution
					FROM #StudentGrades cg
					JOIN ' + @sourceDb + '.edfi.EducationOrganization eo on cg.GraduationSchoolId = eo.EducationOrganizationId
					GROUP BY GraduationSchoolId, NameOfInstitution

					UNION 

					SELECT CourseSchoolId, CourseSchoolName
					FROM #StudentGrades
					GROUP BY CourseSchoolId, CourseSchoolName) AS SOURCE
			ON TARGET.GradRequirementSchoolId = SOURCE.SchoolId
			WHEN MATCHED 
			AND TARGET.GradRequirementSchoolName <> SOURCE.SchoolName	
			THEN UPDATE SET
				GradRequirementSchoolName = SOURCE.SchoolName
			WHEN NOT MATCHED THEN 
				INSERT (GradRequirementSchoolId, GradRequirementSchoolName)
				VALUES (SchoolId, SchoolName)
			WHEN NOT MATCHED BY SOURCE THEN
				DELETE
			OUTPUT $action INTO #GradRequirementSchoolMerge;'
	
		EXEC (@GRSQuery);
			
		UPDATE gradCredits.GradRequirementExecutionLogDetail
		SET RecordsInserted = COALESCE(RecordsInserted, 0) + (SELECT SUM(CASE WHEN MERGE_ACTION='INSERT' THEN 1 ELSE 0 END)
								from #GradRequirementSchoolMerge), 
			RecordsUpdated = COALESCE(RecordsUpdated, 0) + (SELECT SUM(CASE WHEN MERGE_ACTION='UPDATE' THEN 1 ELSE 0 END)
								from #GradRequirementSchoolMerge),
			RecordsDeleted = COALESCE(RecordsDeleted, 0) + (SELECT SUM(CASE WHEN MERGE_ACTION='DELETE' THEN 1 ELSE 0 END)
								from #GradRequirementSchoolMerge)
		WHERE GradRequirementExecutionLogDetailId = @GradRequirementSchoolLogDetailId;

	END TRY

	BEGIN CATCH
		SET @ErrorMessage = ERROR_MESSAGE()

		EXEC gradCredits.LogAudit @GradRequirementSchoolLogDetailId, @ErrorMessage	
		SET @RecordsAuditedCount = @RecordsAuditedCount + 1

	END CATCH

	
	BEGIN TRY
		/**	GradRequirementSchoolYear	**/
		DECLARE @GRSYQuery NVARCHAR(MAX) = 
			'MERGE INTO ' + @destinationDb + '.gradCredits.GradRequirementSchoolYear AS TARGET
			USING (SELECT SchoolYear, CurrentSchoolYear 
					FROM ' + @sourceDb + '.edfi.SchoolYearType) AS SOURCE
			ON TARGET.SchoolYear = SOURCE.SchoolYear
			WHEN MATCHED 
			AND TARGET.CurrentSchoolYearIndicator <> SOURCE.CurrentSchoolYear	
			THEN UPDATE SET
				CurrentSchoolYearIndicator = SOURCE.CurrentSchoolYear
			WHEN NOT MATCHED THEN 
				INSERT (SchoolYear, CurrentSchoolYearIndicator)
				VALUES (SchoolYear, CurrentSchoolYear)
			WHEN NOT MATCHED BY SOURCE THEN
				DELETE
			OUTPUT $action INTO #GradRequirementSchoolYearMerge;'

		EXEC (@GRSYQuery);		

		UPDATE gradCredits.GradRequirementExecutionLogDetail
		SET RecordsInserted = COALESCE(RecordsInserted, 0) + (SELECT SUM(CASE WHEN MERGE_ACTION='INSERT' THEN 1 ELSE 0 END)
								from #GradRequirementSchoolYearMerge), 
			RecordsUpdated = COALESCE(RecordsUpdated, 0) + (SELECT SUM(CASE WHEN MERGE_ACTION='UPDATE' THEN 1 ELSE 0 END)
								from #GradRequirementSchoolYearMerge),
			RecordsDeleted = COALESCE(RecordsDeleted, 0) + (SELECT SUM(CASE WHEN MERGE_ACTION='DELETE' THEN 1 ELSE 0 END)
								from #GradRequirementSchoolYearMerge)
		WHERE GradRequirementExecutionLogDetailId = @GradRequirementSchoolYearLogDetailId;
	END TRY

	BEGIN CATCH
		SET @ErrorMessage = ERROR_MESSAGE()

		EXEC gradCredits.LogAudit @GradRequirementSchoolYearLogDetailId, @ErrorMessage	
		SET @RecordsAuditedCount = @RecordsAuditedCount + 1

		
	END CATCH


	BEGIN TRY
		/**	GradRequirementGradeLevel	**/
		DECLARE @GRGLQuery NVARCHAR(MAX) =
			'MERGE INTO ' + @destinationDb + '.gradCredits.GradRequirementGradeLevel AS TARGET
			USING (SELECT GradeLevelWhenTaken, CASE GradeLevelWhenTaken WHEN ''Twelfth grade'' THEN 12
						WHEN ''Eleventh grade'' THEN 11
						WHEN ''Tenth grade'' THEN 10
						WHEN ''Ninth grade'' THEN 9
						WHEN ''Eighth grade'' THEN 8
						WHEN ''Seventh grade'' THEN 7
						WHEN ''Sixth grade'' THEN 6 ELSE NULL END GradRequirementGradeLevel
					FROM #StudentGrades
					WHERE GradeLevelWhenTaken IS NOT NULL
					GROUP BY GradeLevelWhenTaken) AS SOURCE
			ON TARGET.GradRequirementGradeLevel = SOURCE.GradRequirementGradeLevel	
			WHEN NOT MATCHED THEN 
				INSERT (GradRequirementGradeLevelDescription, GradRequirementGradeLevel)
				VALUES (SOURCE.GradeLevelWhenTaken, SOURCE.GradRequirementGradeLevel)
			WHEN NOT MATCHED BY SOURCE THEN
				DELETE
			OUTPUT $action INTO #GradRequirementGradeLevelMerge;'

		EXEC (@GRGLQuery);

		UPDATE gradCredits.GradRequirementExecutionLogDetail
		SET RecordsInserted = COALESCE(RecordsInserted, 0) + (SELECT SUM(CASE WHEN MERGE_ACTION='INSERT' THEN 1 ELSE 0 END)
								from #GradRequirementGradeLevelMerge), 
			RecordsUpdated = COALESCE(RecordsUpdated, 0) + (SELECT SUM(CASE WHEN MERGE_ACTION='UPDATE' THEN 1 ELSE 0 END)
								from #GradRequirementGradeLevelMerge),
			RecordsDeleted = COALESCE(RecordsDeleted, 0) + (SELECT SUM(CASE WHEN MERGE_ACTION='DELETE' THEN 1 ELSE 0 END)
								from #GradRequirementGradeLevelMerge)
		WHERE GradRequirementExecutionLogDetailId = @GradRequirementGradeLevelLogDetailId;
	END TRY

	BEGIN CATCH
		SET @ErrorMessage = ERROR_MESSAGE()

		EXEC gradCredits.LogAudit @GradRequirementGradeLevelLogDetailId, @ErrorMessage	
		SET @RecordsAuditedCount = @RecordsAuditedCount + 1

		
	END CATCH

	BEGIN TRY
		/**	GradRequirementGradingPeriod	**/
		DECLARE @GRGPQuery NVARCHAR(MAX) =
			'MERGE INTO ' + @destinationDb + '.gradCredits.GradRequirementGradingPeriod AS TARGET
			USING (SELECT GradingPeriod
					FROM #StudentGrades
					WHERE GradingPeriod IS NOT NULL
					GROUP BY GradingPeriod) AS SOURCE
			ON TARGET.GradRequirementGradingPeriod = SOURCE.GradingPeriod	
			WHEN NOT MATCHED THEN 
				INSERT (GradRequirementGradingPeriod)
				VALUES (SOURCE.GradingPeriod)
			WHEN NOT MATCHED BY SOURCE THEN
				DELETE
			OUTPUT $action INTO #GradRequirementGradingPeriodMerge;'

		EXEC (@GRGPQuery);

		UPDATE gradCredits.GradRequirementExecutionLogDetail
		SET RecordsInserted = COALESCE(RecordsInserted, 0) + (SELECT SUM(CASE WHEN MERGE_ACTION='INSERT' THEN 1 ELSE 0 END)
								from #GradRequirementGradingPeriodMerge), 
			RecordsUpdated = COALESCE(RecordsUpdated, 0) + (SELECT SUM(CASE WHEN MERGE_ACTION='UPDATE' THEN 1 ELSE 0 END)
								from #GradRequirementGradingPeriodMerge),
			RecordsDeleted = COALESCE(RecordsDeleted, 0) + (SELECT SUM(CASE WHEN MERGE_ACTION='DELETE' THEN 1 ELSE 0 END)
								from #GradRequirementGradingPeriodMerge)
		WHERE GradRequirementExecutionLogDetailId = @GradRequirementGradingPeriodLogDetailId;
	END TRY

	BEGIN CATCH
		SET @ErrorMessage = ERROR_MESSAGE()

		EXEC gradCredits.LogAudit @GradRequirementGradingPeriodLogDetailId, @ErrorMessage	
		SET @RecordsAuditedCount = @RecordsAuditedCount + 1

	END CATCH


	BEGIN TRY
		/**	GradRequirementStudent	**/
		

		DECLARE @GRSTQuery NVARCHAR(MAX) =
			'MERGE INTO ' + @destinationDb + '.gradCredits.GradRequirementStudent AS TARGET
			USING (SELECT StudentUSI, StudentUniqueId, StudentChartId, StudentDistrictId, StudentName, 
						GraduationSchoolId, grgl.GradRequirementGradeLevelId
					FROM
					(SELECT StudentUSI, StudentUniqueId, StudentChartId, StudentDistrictId, StudentName, 
						GraduationSchoolId, MAX(GradRequirementGradeLevel) GradRequirementGradeLevel
					FROM
						(SELECT StudentUSI, StudentUniqueId, StudentChartId, StudentDistrictId, StudentName, 
							GraduationSchoolId, 
							CASE COALESCE(CurrentGradeLevel, GradeLevelWhenTaken) WHEN ''Twelfth grade'' THEN 12
								WHEN ''Eleventh grade'' THEN 11
								WHEN ''Tenth grade'' THEN 10
								WHEN ''Ninth grade'' THEN 9
								WHEN ''Eighth grade'' THEN 8
								WHEN ''Seventh grade'' THEN 7
								WHEN ''Sixth grade'' THEN 6 ELSE NULL END GradRequirementGradeLevel
						FROM #StudentGrades
						) A 
					GROUP BY StudentUSI, StudentUniqueId, StudentChartId, StudentDistrictId, StudentName, GraduationSchoolId
					) B
					INNER JOIN gradCredits.GradRequirementGradeLevel grgl
						ON B.GradRequirementGradeLevel = grgl.GradRequirementGradeLevel
					) AS SOURCE
			ON TARGET.StudentUniqueId = SOURCE.StudentUniqueId
			WHEN MATCHED 
			AND TARGET.StudentUSI <> SOURCE.StudentUSI
			OR TARGET.StudentChartId <> SOURCE.StudentChartId
			OR TARGET.StudentDistrictId <> SOURCE.StudentDistrictId
			OR TARGET.StudentName <> SOURCE.StudentName
			OR COALESCE(TARGET.GradPathSchoolId, -9999) <> COALESCE(SOURCE.GraduationSchoolId, -9999)
			OR TARGET.CurrentGradeLevelId <> SOURCE.GradRequirementGradeLevelId
			THEN UPDATE SET
				StudentUSI = SOURCE.StudentUSI, 
				StudentUniqueId = SOURCE.StudentUniqueId, 
				StudentChartId = SOURCE.StudentChartId, 
				StudentDistrictId = SOURCE.StudentDistrictId,  
				StudentName = SOURCE.StudentName,
				GradPathSchoolId = SOURCE.GraduationSchoolId,
				CurrentGradeLevelId = SOURCE.GradRequirementGradeLevelId
			WHEN NOT MATCHED THEN 
				INSERT (StudentUSI, StudentUniqueId, StudentChartId, StudentDistrictId, StudentName, GradPathSchoolId, CurrentGradeLevelId)
				VALUES (SOURCE.StudentUSI, SOURCE.StudentUniqueId, SOURCE.StudentChartId, SOURCE.StudentDistrictId, 
					SOURCE.StudentName, SOURCE.GraduationSchoolId, SOURCE.GradRequirementGradeLevelId)
			WHEN NOT MATCHED BY SOURCE THEN
				DELETE
			OUTPUT $action INTO #GradRequirementStudentMerge;'

		EXEC (@GRSTQuery);
		
		

		UPDATE gradCredits.GradRequirementExecutionLogDetail
		SET RecordsInserted = COALESCE(RecordsInserted, 0) + (SELECT SUM(CASE WHEN MERGE_ACTION='INSERT' THEN 1 ELSE 0 END)
								from #GradRequirementStudentMerge), 
			RecordsUpdated = COALESCE(RecordsUpdated, 0) + (SELECT SUM(CASE WHEN MERGE_ACTION='UPDATE' THEN 1 ELSE 0 END)
								from #GradRequirementStudentMerge),
			RecordsDeleted = COALESCE(RecordsDeleted, 0) + (SELECT SUM(CASE WHEN MERGE_ACTION='DELETE' THEN 1 ELSE 0 END)
								from #GradRequirementStudentMerge)
		WHERE GradRequirementExecutionLogDetailId = @GradRequirementStudentLogDetailId;

	END TRY

	BEGIN CATCH
		SET @ErrorMessage = ERROR_MESSAGE()

		EXEC gradCredits.LogAudit @GradRequirementStudentLogDetailId, @ErrorMessage	
		SET @RecordsAuditedCount = @RecordsAuditedCount + 1

	
	END CATCH


	BEGIN TRY
		/**	GradRequirementStudentSchoolAssociation	**/
		DECLARE @GRSSAQuery NVARCHAR(MAX) =
			';WITH StudentSchoolAssociation AS 
			(
				SELECT grs.GradRequirementStudentId, 
					grsc.GradRequirementSchoolId, 
					csg.SchoolYearWhenTaken, 
					grgl.GradRequirementGradeLevelId
				FROM #StudentGrades csg
				INNER JOIN ' + @destinationDb + '.gradCredits.GradRequirementStudent grs
					ON csg.StudentChartId = grs.StudentChartId and csg.StudentDistrictId = grs.StudentDistrictId
					AND csg.StudentUniqueId = grs.StudentUniqueId and csg.StudentUSI = grs.StudentUSI
				INNER JOIN ' + @destinationDb + '.gradCredits.GradRequirementSchool grsc
					ON csg.CourseSchoolId = grsc.GradRequirementSchoolId
				INNER JOIN ' + @destinationDb + '.gradCredits.GradRequirementGradeLevel grgl
					ON csg.GradeLevelWhenTaken = (CASE grgl.GradRequirementGradeLevel WHEN 12 THEN ''Twelfth grade''
													WHEN 11 THEN ''Eleventh grade''
													WHEN 10 THEN ''Tenth grade''
													WHEN 9 THEN ''Ninth grade''
													WHEN 8 THEN ''Eighth grade''
													WHEN 7 THEN ''Seventh grade''
													WHEN 6 THEN ''Sixth grade'' ELSE NULL END)
				GROUP BY 
					grs.GradRequirementStudentId, 
					grsc.GradRequirementSchoolId, 
					csg.SchoolYearWhenTaken, 
					grgl.GradRequirementGradeLevelId
			)
			MERGE INTO ' + @destinationDb + '.gradCredits.GradRequirementStudentSchoolAssociation AS TARGET
			USING StudentSchoolAssociation AS SOURCE
			ON TARGET.GradRequirementStudentId = SOURCE.GradRequirementStudentId
			AND TARGET.GradRequirementSchoolId = SOURCE.GradRequirementSchoolId
			AND TARGET.SchoolYear = SOURCE.SchoolYearWhenTaken
			AND TARGET.GradRequirementGradeLevelId = SOURCE.GradRequirementGradeLevelId
			WHEN NOT MATCHED THEN 
				INSERT (GradRequirementStudentId, GradRequirementSchoolId, SchoolYear, GradRequirementGradeLevelId)
				VALUES (SOURCE.GradRequirementStudentId, SOURCE.GradRequirementSchoolId, SOURCE.SchoolYearWhenTaken, 
					SOURCE.GradRequirementGradeLevelId)
			WHEN NOT MATCHED BY SOURCE THEN
				DELETE
			OUTPUT $action INTO #GradRequirementSSAMerge;'

		EXEC (@GRSSAQuery);

	
		UPDATE gradCredits.GradRequirementExecutionLogDetail
		SET RecordsInserted = COALESCE(RecordsInserted, 0) + (SELECT SUM(CASE WHEN MERGE_ACTION='INSERT' THEN 1 ELSE 0 END)
								from #GradRequirementSSAMerge), 
			RecordsUpdated = COALESCE(RecordsUpdated, 0) + (SELECT SUM(CASE WHEN MERGE_ACTION='UPDATE' THEN 1 ELSE 0 END)
								from #GradRequirementSSAMerge),
			RecordsDeleted = COALESCE(RecordsDeleted, 0) + (SELECT SUM(CASE WHEN MERGE_ACTION='DELETE' THEN 1 ELSE 0 END)
								from #GradRequirementSSAMerge)
		WHERE GradRequirementExecutionLogDetailId = @GradRequirementSSALogDetailId;
	END TRY

	BEGIN CATCH
		SET @ErrorMessage = ERROR_MESSAGE()

		EXEC gradCredits.LogAudit @GradRequirementSSALogDetailId, @ErrorMessage	
		SET @RecordsAuditedCount = @RecordsAuditedCount + 1

	END CATCH


	BEGIN TRY
		/**	GradRequirementStudentGrade	**/
		DECLARE @GRSGQuery NVARCHAR(MAX) =
			'MERGE INTO ' + @destinationDb + '.gradCredits.GradRequirementStudentGrade AS TARGET
			USING (SELECT grs.GradRequirementStudentId, 
					grsa.GradRequirementStudentSchoolAssociationId,
					csg.CourseCode,
					SUBSTRING(CourseCode, 1,(IIF(CHARINDEX(''_Q'',CourseCode) > 0, CHARINDEX(''_Q'',CourseCode)-1,LEN(CourseCode)))) DisplayCourseCode,
					ISNULL(csg.CourseTitle, SUBSTRING(CourseCode, 1,(IIF(CHARINDEX(''_Q'',CourseCode) > 0, CHARINDEX(''_Q'',CourseCode)-1,LEN(CourseCode))))) CourseTitle,
					csg.Term,
					grgp.GradRequirementGradingPeriodId,
					csg.LetterGradeEarned,
					csg.EarnedCredits,
					CASE Status WHEN ''Pass'' THEN 1 ELSE 0 END PassingGradeIndicator,
					GradeSource
				FROM #StudentGrades csg
				INNER JOIN ' + @destinationDb + '.gradCredits.GradRequirementStudent grs
					ON csg.StudentChartId = grs.StudentChartId and csg.StudentDistrictId = grs.StudentDistrictId
					AND csg.StudentUniqueId = grs.StudentUniqueId and csg.StudentUSI = grs.StudentUSI
				INNER JOIN ' + @destinationDb + '.gradCredits.GradRequirementSchool grsc
					ON csg.CourseSchoolId = grsc.GradRequirementSchoolId
				INNER JOIN ' + @destinationDb + '.gradCredits.GradRequirementGradeLevel grgl
					ON csg.GradeLevelWhenTaken = (CASE grgl.GradRequirementGradeLevel WHEN 12 THEN ''Twelfth grade''
													WHEN 11 THEN ''Eleventh grade''
													WHEN 10 THEN ''Tenth grade''
													WHEN 9 THEN ''Ninth grade''
													WHEN 8 THEN ''Eighth grade''
													WHEN 7 THEN ''Seventh grade''
													WHEN 6 THEN ''Sixth grade'' ELSE NULL END)
				INNER JOIN ' + @destinationDb + '.gradCredits.GradRequirementStudentSchoolAssociation grsa
					ON grs.GradRequirementStudentId = grsa.GradRequirementStudentId
					AND grsc.GradRequirementSchoolId = grsa.GradRequirementSchoolId
					AND csg.SchoolYearWhenTaken = grsa.SchoolYear
					AND grgl.GradRequirementGradeLevelId = grsa.GradRequirementGradeLevelId
				LEFT JOIN ' + @destinationDb + '.gradCredits.GradRequirementGradingPeriod grgp
					ON csg.GradingPeriod = grgp.GradRequirementGradingPeriod	
				GROUP BY 
					grs.GradRequirementStudentId, 
					grsa.GradRequirementStudentSchoolAssociationId,
					csg.CourseCode,
					csg.CourseTitle,
					csg.Term,
					grgp.GradRequirementGradingPeriodId,
					csg.LetterGradeEarned,
					csg.EarnedCredits,
					CASE Status WHEN ''Pass'' THEN 1 ELSE 0 END,
					GradeSource) AS SOURCE
			ON TARGET.GradRequirementStudentId = SOURCE.GradRequirementStudentId
			AND TARGET.GradRequirementStudentSchoolAssociationId = SOURCE.GradRequirementStudentSchoolAssociationId
			AND TARGET.CourseCode = SOURCE.CourseCode
			AND TARGET.Term = SOURCE.Term
			AND TARGET.EarnedCredits = SOURCE.EarnedCredits
			AND TARGET.PassingGradeIndicator = SOURCE.PassingGradeIndicator
			AND COALESCE(TARGET.GradRequirementGradingPeriodId, -9999) = COALESCE(SOURCE.GradRequirementGradingPeriodId,-9999)
			AND COALESCE(TARGET.LetterGradeEarned, ''@ERR'') = COALESCE(SOURCE.LetterGradeEarned,''@ERR'')
			WHEN MATCHED 
			AND TARGET.DisplayCourseCode <> SOURCE.DisplayCourseCode
			AND TARGET.CourseTitle <> SOURCE.CourseTitle	
			AND TARGET.GradeSource <> SOURCE.GradeSource	
			THEN UPDATE SET
				DisplayCourseCode = SOURCE.DisplayCourseCode,
				CourseTitle = SOURCE.CourseTitle,		
				GradeSource = SOURCE.GradeSource
			WHEN NOT MATCHED THEN 
				INSERT (GradRequirementStudentId, GradRequirementStudentSchoolAssociationId, CourseCode, DisplayCourseCode, CourseTitle, Term, 
					GradRequirementGradingPeriodId, LetterGradeEarned, EarnedCredits, PassingGradeIndicator, GradeSource)
				VALUES (SOURCE.GradRequirementStudentId, SOURCE.GradRequirementStudentSchoolAssociationId, SOURCE.CourseCode, SOURCE.DisplayCourseCode, 
					SOURCE.CourseTitle, SOURCE.Term, SOURCE.GradRequirementGradingPeriodId, SOURCE.LetterGradeEarned, SOURCE.EarnedCredits, SOURCE.PassingGradeIndicator, SOURCE.GradeSource)
			WHEN NOT MATCHED BY SOURCE THEN
				DELETE
			OUTPUT $action INTO #GradRequirementStudentGradeMerge;'

		EXEC (@GRSGQuery);

		UPDATE gradCredits.GradRequirementExecutionLogDetail
		SET RecordsInserted = COALESCE(RecordsInserted,0) + (SELECT SUM(CASE WHEN MERGE_ACTION='INSERT' THEN 1 ELSE 0 END)
								from #GradRequirementStudentGradeMerge), 
			RecordsUpdated = COALESCE(RecordsUpdated,0) + (SELECT SUM(CASE WHEN MERGE_ACTION='UPDATE' THEN 1 ELSE 0 END)
								from #GradRequirementStudentGradeMerge),
			RecordsDeleted = COALESCE(RecordsDeleted,0) + (SELECT SUM(CASE WHEN MERGE_ACTION='DELETE' THEN 1 ELSE 0 END)
								from #GradRequirementStudentGradeMerge)
		WHERE GradRequirementExecutionLogDetailId = @GradRequirementStudentGradeLogDetailId;
	END TRY

	BEGIN CATCH
		SET @ErrorMessage = ERROR_MESSAGE()

		EXEC gradCredits.LogAudit @GradRequirementStudentGradeLogDetailId, @ErrorMessage	
		SET @RecordsAuditedCount = @RecordsAuditedCount + 1

	
	END CATCH

	
	
	UPDATE gradCredits.GradRequirementExecutionLog
	SET ExecutionEnd = GETDATE(),
		ExecutionStatus = 'Success'
	WHERE GradRequirementExecutionLogId = @ExecutionLogId

	
	DROP TABLE #StudentGrades;
	DROP TABLE #StudentData;
	DROP TABLE #CourseTranscriptGradesDataOnly;
	DROP TABLE #CummulativeGrades;
	DROP TABLE #CurrentGradesDataWithEarnedCredits;
	DROP TABLE #GradRequirementGradeLevelMerge;
	DROP TABLE #GradRequirementGradingPeriodMerge;
	DROP TABLE #GradRequirementSchoolMerge;
	DROP TABLE #GradRequirementSchoolYearMerge
	DROP TABLE #GradRequirementSSAMerge;
	DROP TABLE #GradRequirementStudentGradeMerge;
	DROP TABLE #GradRequirementStudentMerge
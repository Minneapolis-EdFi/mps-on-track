

/****	GetStudentChartData	***/
IF OBJECT_ID('gradCredits.GetStudentChartData', 'TF') IS NOT NULL
    DROP FUNCTION gradCredits.GetStudentChartData
GO



CREATE FUNCTION gradCredits.GetStudentChartData 
	(@StudentId INT)
RETURNS 
	@StudentChartData TABLE (StudentUniqueId INT, 
							StudentName NVARCHAR(500),
							LastGradedGradingPeriod NVARCHAR(10),
							CurrentGradeLevel NVARCHAR(50),
							GradRequirement NVARCHAR(50),
							GradRequirementGroup NVARCHAR(50),
							EarnedGradCredits DECIMAL(6,3),
							RemainingCreditsRequiredByLastGradedQuarter DECIMAL(6,3),
							RemainingCreditsRequiredByEndOfCurrentGradeLevel DECIMAL(6,3),
							RemainingCreditsRequiredByGraduation DECIMAL(6,3),
							DifferentialRemainingCreditsRequiredByGraduation DECIMAL(6,3),
							TotalEarnedCredits DECIMAL(6,3),
							TotalEarnedGradCredits DECIMAL(6,3),
							CreditValueRequired DECIMAL(6,3),
							CreditValueRemaining DECIMAL(6,3),
							DisplayOrder INT
						)

AS
	BEGIN

		INSERT INTO @StudentChartData
		SELECT grs.StudentUniqueId,
			CONCAT('[',grs.StudentChartId,'] ', grs.StudentName),
			grgp.GradRequirementGradingPeriod,
			grgl.GradRequirementGradeLevelDescription,
			gr.GradRequirement,
			GradRequirementDepartment,
			grsc.EarnedCredits,
			grsc.RemainingCreditsRequiredByLastGradedQuarter,
			grsc.RemainingCreditsRequiredByEndOfCurrentGradeLevel,
			grsc.RemainingCreditsRequiredByGraduation,
			grsc.DifferentialRemainingCreditsRequiredByGraduation,
			grsc.TotalEarnedCredits,
			grsc.TotalEarnedGradCredits,
			grsc.CreditValueRequired,
			grsc.CreditValueRemaining,
			CASE 
				WHEN GradRequirement = 'ELA 9' THEN 1 
				WHEN GradRequirement = 'ELA 10' THEN 2 
				WHEN GradRequirement = 'ELA 11' THEN 3
				WHEN GradRequirement = 'ELA 12' THEN 4 
				WHEN GradRequirement = 'Geography' THEN 5 
				WHEN GradRequirement = 'US History' THEN 6 
				WHEN GradRequirement = 'World History' THEN 7 
				WHEN GradRequirement = 'Government and Citizenship' THEN 8 
				WHEN GradRequirement = 'Economics' THEN 9 
				WHEN GradRequirement = 'Intermediate Algebra' THEN 10 
				WHEN GradRequirement = 'Geometry' THEN 11 
				WHEN GradRequirement = 'Advanced Algebra' THEN 12
				WHEN GradRequirement = 'Physical Science' THEN 13
				WHEN GradRequirement = 'Physics' THEN 13
				WHEN GradRequirement = 'Biology' THEN 14 
				WHEN GradRequirement = 'Chemistry' THEN 15 
				WHEN GradRequirement = 'Chemistry or Physics' THEN 15 
				WHEN GradRequirement = 'Fine Arts' THEN 16 
				WHEN GradRequirement = 'Physical Education' THEN 17 
				WHEN GradRequirement = 'Health' THEN 18 				
				WHEN GradRequirement = 'Electives' THEN 19 
				END
		FROM gradCredits.GradRequirementStudentCredit grsc
		INNER JOIN gradCredits.GradRequirementStudent grs 
			on grsc.GradRequirementStudentId = grs.GradRequirementStudentId
		INNER JOIN gradCredits.GradRequirementGradingPeriod grgp 
			on grsc.LastGradedGradingPeriodId = grgp.GradRequirementGradingPeriodId
		INNER JOIN gradCredits.GradRequirementGradeLevel grgl
			on grs.CurrentGradeLevelId = grgl.GradRequirementGradeLevelId
		INNER JOIN gradCredits.GradRequirement gr
			on grsc.GradRequirementId = gr.GradRequirementId
		INNER JOIN 
			(
				SELECT GradRequirementDepartment, gr.GradRequirementId, gr.GradRequirementSelectorId
				FROM gradCredits.GradRequirementReference gr
				INNER JOIN gradCredits.GradRequirementDepartment d
					ON d.GradRequirementDepartmentId = gr.GradRequirementDepartmentId
				GROUP BY GradRequirementDepartment, gr.GradRequirementId,  gr.GradRequirementSelectorId
			)Department
			on grs.GradRequirementSelectorId = Department.GradRequirementSelectorId
			and grsc.GradRequirementId = Department.GradRequirementId
		WHERE grs.StudentUniqueId = @StudentId



		RETURN
	END
GO




/****	GetStudentRawGrades	***/
IF OBJECT_ID('gradCredits.GetStudentRawGrades', 'TF') IS NOT NULL
    DROP FUNCTION gradCredits.GetStudentRawGrades
GO



CREATE FUNCTION gradCredits.GetStudentRawGrades 
	(@StudentId INT)
RETURNS 
	@StudentGrades TABLE (StudentUniqueId INT, 
							StudentName NVARCHAR(500),
							GradRequirement NVARCHAR(200), 
							GradingPeriod NVARCHAR(10),
							CourseDetails NVARCHAR(500),
							GradeDetails NVARCHAR(500),	
							LetterGradeEarned NVARCHAR(10),
							EarnedCredits DECIMAL(6,3), 
							Status NVARCHAR(50),
							DisplayOrder INT
						)

AS
	BEGIN

		INSERT INTO @StudentGrades
		SELECT grs.StudentUniqueId,
			CONCAT('[',grs.StudentChartId,'] ', grs.StudentName),
			grcs.SpecificGradRequirement,
			grgp.GradRequirementGradingPeriod,
			REPLACE(CONCAT(DisplayCourseCode, ': ', CourseTitle,' [Sequence: ', grcs.CourseCode, ' ', ISNULL(SpecificGradRequirement,'N/A'),' ', ISNULL(FirstSequenceGradRequirement,''), ' ',
				ISNULL(SecondSequenceGradRequirement, ''), ' ', ISNULL(ThirdSequenceGradRequirement,' '), ' ', ISNULL(FourthSequenceGradRequirement,''),']'),'  ',''),
			CONCAT(Term,' ', grssa.SchoolYear, ': ', grgl.GradRequirementGradeLevelDescription, ': ',grsh.GradRequirementSchoolName) GradeDetails,
			LetterGradeEarned,
			EarnedCredits,
			CASE WHEN grcs.SpecificGradRequirement IS NULL THEN 'Does not count: Course Sequence Not Found'
				 WHEN PassingGradeIndicator = 1 THEN 'Counts'
				 ELSE 'Does not count: Course Not Passed' END,
			ROW_NUMBER() OVER (ORDER BY grssa.SchoolYear ASC, CASE TERM WHEN 'Fall' THEN 0 WHEN 'Spring' THEN 1 WHEN 'Summer' THEN 2 END) 
		FROM gradCredits.GradRequirementStudentGrade grsg
		INNER JOIN gradCredits.GradRequirementStudent grs 
			on grsg.GradRequirementStudentId = grs.GradRequirementStudentId
		INNER JOIN gradCredits.GradRequirementStudentSchoolAssociation grssa
			on grsg.GradRequirementStudentSchoolAssociationId = grssa.GradRequirementStudentSchoolAssociationId		
		INNER JOIN gradCredits.GradRequirementGradeLevel grgl
			on grssa.GradRequirementGradeLevelId = grgl.GradRequirementGradeLevelId
		INNER JOIN gradCredits.GradRequirementSchool grsh
			on grssa.GradRequirementSchoolId = grsh.GradRequirementSchoolId
		LEFT JOIN gradCredits.GradRequirementGradingPeriod grgp 
			on grsg.GradRequirementGradingPeriodId = grgp.GradRequirementGradingPeriodId
		LEFT JOIN 
			(SELECT GradRequirementCourseSequenceId,
				grcs.CourseCode,
				gr.GradRequirement SpecificGradRequirement,
				gr1.GradRequirement FirstSequenceGradRequirement,
				gr2.GradRequirement SecondSequenceGradRequirement,
				gr3.GradRequirement ThirdSequenceGradRequirement,
				gr4.GradRequirement FourthSequenceGradRequirement
			FROM gradCredits.GradRequirementCourseSequence grcs
			LEFT JOIN gradCredits.GradRequirement gr
				on grcs.SpecificGradRequirementId = gr.GradRequirementId
			LEFT JOIN gradCredits.GradRequirement gr1
				on grcs.FirstSequenceGradRequirementId = gr1.GradRequirementId
			LEFT JOIN gradCredits.GradRequirement gr2
				on grcs.SecondSequenceGradRequirementId = gr2.GradRequirementId
			LEFT JOIN gradCredits.GradRequirement gr3
				on grcs.ThirdSequenceGradRequirementId = gr3.GradRequirementId
			LEFT JOIN gradCredits.GradRequirement gr4
				on grcs.FourthSequenceGradRequirementId = gr4.GradRequirementId
			GROUP BY GradRequirementCourseSequenceId, gr.GradRequirement, gr1.GradRequirement, 
				gr2.GradRequirement, gr3.GradRequirement, gr4.GradRequirement,grcs.CourseCode) grcs
			on grsg.GradRequirementCourseSequenceId = grcs.GradRequirementCourseSequenceId
		WHERE grs.StudentUniqueId = @StudentId
		ORDER BY grssa.SchoolYear, GradeDetails

		RETURN
	END
GO



/****	GetStudentChartDataGrades	***/
IF OBJECT_ID('gradCredits.GetStudentChartDataGrades', 'TF') IS NOT NULL
    DROP FUNCTION gradCredits.GetStudentChartDataGrades
GO


CREATE FUNCTION gradCredits.GetStudentChartDataGrades 
	(@StudentId INT)
RETURNS 
	@StudentChartDataGrades TABLE (StudentUniqueId INT, 
							StudentName NVARCHAR(500),	
							CurrentGradeLevel NVARCHAR(50),
							LastGradedQuarter NVARCHAR(50),						
							GradRequirement NVARCHAR(50),
							GradRequirementGroup NVARCHAR(50),	
							CourseDetails NVARCHAR(500),
							GradeDetails NVARCHAR(500),								
							CreditsContributedByCourse DECIMAL(6,3), 
							CourseCreditsReported DECIMAL(6,3), 
							LetterGradeEarned NVARCHAR(10),
							GradingPeriod NVARCHAR(10),
							WhenTakenGradeLevel NVARCHAR(50),
							SchoolYearWhenTaken SMALLINT,
							Term VARCHAR(50),
							Status NVARCHAR(50),
							EarnedGradCredits DECIMAL(6,3),
							RemainingCreditsRequiredByLastGradedQuarter DECIMAL(6,3),
							RemainingCreditsRequiredByEndOfCurrentGradeLevel DECIMAL(6,3),
							RemainingCreditsRequiredByGraduation DECIMAL(6,3),
							DifferentialRemainingCreditsRequiredByGraduation DECIMAL(6,3),
							TotalEarnedCredits DECIMAL(6,3),
							TotalEarnedGradCredits DECIMAL(6,3),
							CreditValueRequired DECIMAL(6,3),
							CreditValueRemaining DECIMAL(6,3),
							CreditDeficiencyStatus NVARCHAR(25),
							DisplayOrder INT
						)

AS
	BEGIN

		INSERT INTO @StudentChartDataGrades		
		SELECT StudentUniqueId,
			CONCAT('[',grs.StudentChartId,'] ', grs.StudentName),	
			grgll.GradRequirementGradeLevelDescription CurrentGradeLevel,	
			LastGradedQuarter,	
			gr.GradRequirement,
			GradRequirementDepartment,			
			NULLIF(REPLACE(CONCAT(DisplayCourseCode, ': ', CourseTitle,' [Sequence: ', grcs.CourseCode, ' ', ISNULL(SpecificGradRequirement,'N/A'),' ', ISNULL(FirstSequenceGradRequirement,''), ' ',
				ISNULL(SecondSequenceGradRequirement, ''), ' ', ISNULL(ThirdSequenceGradRequirement,' '), ' ', ISNULL(FourthSequenceGradRequirement,''),']'),'  ',''),':[Sequence:N/A ]'),
			NULLIF(CONCAT(Term,' ', grssa.SchoolYear, ': ', grgl.GradRequirementGradeLevelDescription, ': ',grsh.GradRequirementSchoolName),' : : ') GradeDetails,			
			CreditsContributed,
			grsg.EarnedCredits CourseCredits,
			LetterGradeEarned,
			grgp.GradRequirementGradingPeriod,
			grgl.GradRequirementGradeLevelDescription,		
			grssa.SchoolYear,
			Term,
			CASE WHEN DisplayCourseCode IS NULL THEN NULL
				WHEN DisplayCourseCode IS NOT NULL AND grcs.SpecificGradRequirement IS NULL THEN 'Does not count: Course Sequence Not Found'
				WHEN PassingGradeIndicator = 1 THEN 'Counts'
				ELSE 'Counts: Course Not Passed' END, 
			grsc.EarnedCredits,
			grsc.RemainingCreditsRequiredByLastGradedQuarter,
			grsc.RemainingCreditsRequiredByEndOfCurrentGradeLevel,
			grsc.RemainingCreditsRequiredByGraduation,
			grsc.DifferentialRemainingCreditsRequiredByGraduation,
			grsc.TotalEarnedCredits,
			grsc.TotalEarnedGradCredits,
			grsc.CreditValueRequired,
			grsc.CreditValueRemaining,
			grsc.CreditDeficiencyStatus,
			ROW_NUMBER() OVER (ORDER BY grssa.SchoolYear ASC, CASE TERM WHEN 'Fall' THEN 0 WHEN 'Spring' THEN 1 WHEN 'Summer' THEN 2 WHEN NULL THEN 3 END) 
		FROM gradCredits.GradRequirementStudentCredit grsc	
		INNER JOIN gradCredits.GradRequirement gr
			on grsc.GradRequirementId = gr.GradRequirementId
		LEFT JOIN gradCredits.GradRequirementStudentCreditGrade grscg
			on grscg.GradRequirementStudentCreditId = grsc.GradRequirementStudentCreditId 
		LEFT JOIN gradCredits.GradRequirementStudentGrade grsg
			on grscg.GradRequirementStudentGradeId = grsg.GradRequirementStudentGradeId 
		LEFT JOIN 
			(
				SELECT gc.GradRequirementStudentId, 
					GradRequirementGradingPeriod LastGradedQuarter
				FROM gradCredits.GradRequirementStudentCredit gc
				INNER JOIN gradCredits.GradRequirementGradingPeriod gp
					ON gc.LastGradedGradingPeriodId = gp.GradRequirementGradingPeriodId
				GROUP BY gc.GradRequirementStudentId, GradRequirementGradingPeriod			
			) lgq
			ON lgq.GradRequirementStudentId = grsc.GradRequirementStudentId	
		LEFT JOIN gradCredits.GradRequirementStudent grs 
			on grsc.GradRequirementStudentId = grs.GradRequirementStudentId 
		LEFT JOIN gradCredits.GradRequirementGradeLevel grgll
			on grs.CurrentGradeLevelId = grgll.GradRequirementGradeLevelId
		LEFT JOIN gradCredits.GradRequirementStudentSchoolAssociation grssa
			on grsg.GradRequirementStudentSchoolAssociationId = grssa.GradRequirementStudentSchoolAssociationId	
		LEFT JOIN gradCredits.GradRequirementSchool grsh
			on grssa.GradRequirementSchoolId = grsh.GradRequirementSchoolId	
		LEFT JOIN gradCredits.GradRequirementGradeLevel grgl
			on grssa.GradRequirementGradeLevelId = grgl.GradRequirementGradeLevelId	
		LEFT JOIN 
			(
				SELECT GradRequirementDepartment, gr.GradRequirementId, gr.GradRequirementSelectorId
				FROM gradCredits.GradRequirementReference gr
				INNER JOIN gradCredits.GradRequirementDepartment d
					ON d.GradRequirementDepartmentId = gr.GradRequirementDepartmentId
				GROUP BY GradRequirementDepartment, gr.GradRequirementId,  gr.GradRequirementSelectorId
			)Department
			on grs.GradRequirementSelectorId = Department.GradRequirementSelectorId
			and grsc.GradRequirementId = Department.GradRequirementId	
		LEFT JOIN gradCredits.GradRequirementGradingPeriod grgp 
			on grsg.GradRequirementGradingPeriodId = grgp.GradRequirementGradingPeriodId
		LEFT JOIN 
			(SELECT GradRequirementCourseSequenceId,
				grcs.CourseCode,
				gr.GradRequirement SpecificGradRequirement,
				gr1.GradRequirement FirstSequenceGradRequirement,
				gr2.GradRequirement SecondSequenceGradRequirement,
				gr3.GradRequirement ThirdSequenceGradRequirement,
				gr4.GradRequirement FourthSequenceGradRequirement
			FROM gradCredits.GradRequirementCourseSequence grcs
			LEFT JOIN gradCredits.GradRequirement gr
				on grcs.SpecificGradRequirementId = gr.GradRequirementId
			LEFT JOIN gradCredits.GradRequirement gr1
				on grcs.FirstSequenceGradRequirementId = gr1.GradRequirementId
			LEFT JOIN gradCredits.GradRequirement gr2
				on grcs.SecondSequenceGradRequirementId = gr2.GradRequirementId
			LEFT JOIN gradCredits.GradRequirement gr3
				on grcs.ThirdSequenceGradRequirementId = gr3.GradRequirementId
			LEFT JOIN gradCredits.GradRequirement gr4
				on grcs.FourthSequenceGradRequirementId = gr4.GradRequirementId
			GROUP BY GradRequirementCourseSequenceId, gr.GradRequirement, gr1.GradRequirement, 
				gr2.GradRequirement, gr3.GradRequirement, gr4.GradRequirement,grcs.CourseCode) grcs
			on grsg.GradRequirementCourseSequenceId = grcs.GradRequirementCourseSequenceId
		WHERE grs.StudentUniqueId = @StudentId


		RETURN
	END
GO



/****	GetStudentData	***/
IF OBJECT_ID('gradCredits.GetStudentData', 'TF') IS NOT NULL
    DROP FUNCTION gradCredits.GetStudentData
GO


CREATE FUNCTION gradCredits.GetStudentData 
	(@StudentId INT)
RETURNS 
	@StudentData TABLE (StudentUniqueId INT, 
							StudentName NVARCHAR(500),
							GradPathSchoolName NVARCHAR(50),	
							LastGradedQuarter NVARCHAR(50),
							CurrentGradeLevel NVARCHAR(50),								
							CreditDeficiencyStatus NVARCHAR(50),
							TotalEarnedCredits DECIMAL(6,3),
							TotalEarnedGradCredits DECIMAL(6,3)							
						)

AS
	BEGIN

		INSERT INTO @StudentData
		SELECT StudentUniqueId,
			CONCAT('[',grs.StudentChartId,'] ', grs.StudentName),	
			grsl.GradRequirementSelector,
			LastGradedQuarter,
			grl.GradRequirementGradeLevelDescription CurrentGradeLevel,
			CreditDeficiencyStatus,
			TotalEarnedCredits,
			TotalEarnedGradCredits
		FROM gradCredits.GradRequirementStudent grs
		INNER JOIN gradCredits.GradRequirementSelector grsl
			ON grs.GradRequirementSelectorId = grsl.GradRequirementSelectorId
		INNER JOIN 
			(
				SELECT gc.GradRequirementStudentId, 
					GradRequirementGradingPeriod LastGradedQuarter,
					TotalEarnedCredits,
					TotalEarnedGradCredits,
					CASE WHEN NotMetCount > 0 
					THEN 'Not Meeting Grad Requirements' 
					ELSE 'Meeting Grad Requirements' END CreditDeficiencyStatus
				FROM gradCredits.GradRequirementStudentCredit gc
				INNER JOIN gradCredits.GradRequirementGradingPeriod gp
					ON gc.LastGradedGradingPeriodId = gp.GradRequirementGradingPeriodId
				LEFT JOIN 
					(
						SELECT GradRequirementStudentId, COUNT(1) NotMetCount
						FROM gradCredits.GradRequirementStudentCredit
						WHERE RemainingCreditsRequiredByLastGradedQuarter > 0
						GROUP BY GradRequirementStudentId
					) nmc
					ON gc.GradRequirementStudentId = nmc.GradRequirementStudentId				
				GROUP BY gc.GradRequirementStudentId, GradRequirementGradingPeriod, NotMetCount, TotalEarnedCredits, TotalEarnedGradCredits			
			) lgq
			ON lgq.GradRequirementStudentId = grs.GradRequirementStudentId
		INNER JOIN gradCredits.GradRequirementGradeLevel grl
			ON grs.CurrentGradeLevelId = grl.GradRequirementGradeLevelId
		WHERE grs.StudentUniqueId = @StudentId

		RETURN
	END
GO




/****	GetGradRequirementStudentGroupId	***/
IF OBJECT_ID('gradCredits.GetGradRequirementStudentGroupId', 'P') IS NOT NULL
    DROP PROCEDURE gradCredits.GetGradRequirementStudentGroupId
GO

CREATE PROCEDURE gradCredits.GetGradRequirementStudentGroupId
	@StudentGroup NVARCHAR(100),
	@StudentGroupId INT OUTPUT
AS
	IF @StudentGroup IS NOT NULL
	AND NOT EXISTS
	(
		SELECT 1
		FROM gradCredits.GradRequirementStudentGroup
		WHERE GradRequirementStudentGroup = @StudentGroup
	) 
	BEGIN
		INSERT INTO gradCredits.GradRequirementStudentGroup
		SELECT @StudentGroup
	END	
	
	SET @StudentGroupId = COALESCE((SELECT GradRequirementStudentGroupId
		FROM gradCredits.GradRequirementStudentGroup
		WHERE GradRequirementStudentGroup = @StudentGroup),-1)	
GO




/****	GetGradRequirementSelectorId	***/
IF OBJECT_ID('gradCredits.GetGradRequirementSelectorId', 'P') IS NOT NULL
    DROP PROCEDURE gradCredits.GetGradRequirementSelectorId
GO


CREATE PROCEDURE gradCredits.GetGradRequirementSelectorId
	@Selector NVARCHAR(50),
	@SchoolId INT,
	@StudentGroupId INT NULL,
	@SelectorId INT OUTPUT
AS
	BEGIN
		INSERT INTO gradCredits.GradRequirementSchool
		SELECT @SchoolId, @Selector
		WHERE 
			@Selector IS NOT NULL
			AND @SchoolId IS NOT NULL
			AND NOT EXISTS 
			(SELECT 1 
			FROM gradCredits.GradRequirementSchool 
			WHERE GradRequirementSchoolId = @SchoolId 
			AND GradRequirementSchoolName = @Selector)

		
		IF @SchoolId IN (SELECT GradRequirementSchoolId FROM gradCredits.GradRequirementSchool)
		AND (@StudentGroupId IS NULL OR (@StudentGroupId IN (SELECT GradRequirementStudentGroupId FROM gradCredits.GradRequirementStudentGroup)))
		AND @Selector IN (SELECT GradRequirementSchoolName FROM gradCredits.GradRequirementSchool)
			BEGIN
				SELECT @SelectorId = grs.GradRequirementSelectorId
				FROM gradCredits.GradRequirementSelector grs			
				WHERE grs.GradRequirementSchoolId = @SchoolId
				AND COALESCE(grs.GradRequirementStudentGroupId,-9999) = COALESCE(@StudentGroupId,-9999)
				AND grs.GradRequirementSelector = @Selector
				
				IF @@ROWCOUNT = 0 
					BEGIN
						INSERT INTO gradCredits.GradRequirementSelector(GradRequirementSelector, GradRequirementSchoolId, GradRequirementStudentGroupId)
						SELECT @Selector, @SchoolId, @StudentGroupId

						SELECT @SelectorId = grs.GradRequirementSelectorId
						FROM gradCredits.GradRequirementSelector grs			
						WHERE grs.GradRequirementSchoolId = @SchoolId
						AND COALESCE(grs.GradRequirementStudentGroupId,-9999) = COALESCE(@StudentGroupId,-9999)
						AND grs.GradRequirementSelector = @Selector
					END
			END
		ELSE
			SET @SelectorId = -1
	
	END
GO



/****	GetGradRequirementId	***/
IF OBJECT_ID('gradCredits.GetGradRequirementId', 'P') IS NOT NULL
    DROP PROCEDURE gradCredits.GetGradRequirementId
GO



CREATE PROCEDURE gradCredits.GetGradRequirementId 
	@GradRequirement NVARCHAR(200),	
	@GradRequirementId INT OUTPUT
AS
	BEGIN

		IF @GradRequirement = 'Elective' 
			SET @GradRequirement = 'Electives'		
		IF @GradRequirement IS NOT NULL		
		AND NOT EXISTS
		(
			SELECT 1
			FROM gradCredits.GradRequirement 
			WHERE GradRequirement = @GradRequirement			
		) 
		BEGIN
			INSERT INTO gradCredits.GradRequirement
			SELECT @GradRequirement
		END	
	
		SET @GradRequirementId = COALESCE((SELECT GradRequirementId
			FROM gradCredits.GradRequirement
			WHERE GradRequirement = @GradRequirement),-1)	
	
	END
GO



/****	GetGradRequirementDepartmentId	***/
IF OBJECT_ID('gradCredits.GetGradRequirementDepartmentId', 'P') IS NOT NULL
    DROP PROCEDURE gradCredits.GetGradRequirementDepartmentId
GO



CREATE PROCEDURE gradCredits.GetGradRequirementDepartmentId 
	@GradRequirementDepartment  NVARCHAR(200),	
	@GradRequirementDepartmentId  INT OUTPUT
AS
	BEGIN
		IF @GradRequirementDepartment IS NOT NULL		
		AND NOT EXISTS
		(
			SELECT 1
			FROM gradCredits.GradRequirementDepartment 
			WHERE GradRequirementDepartment = @GradRequirementDepartment		
		) 
		BEGIN
			INSERT INTO gradCredits.GradRequirementDepartment
			SELECT @GradRequirementDepartment
		END	
	
		SET @GradRequirementDepartmentId = COALESCE((SELECT GradRequirementDepartmentId
			FROM gradCredits.GradRequirementDepartment
			WHERE GradRequirementDepartment = @GradRequirementDepartment),-1)	
	
	END
GO




/****	LoadGradReference	***/
IF OBJECT_ID('gradCredits.LoadGradReference', 'P') IS NOT NULL
    DROP PROCEDURE gradCredits.LoadGradReference
GO


CREATE PROCEDURE gradCredits.LoadGradReference

	@FILE_NAME NVARCHAR(300) NULL	

AS

SET NOCOUNT ON

	IF @FILE_NAME IS NULL 
		SET @FILE_NAME = 'C:\GraduationCreditsImplementation\GraduationPathTemplate.csv'
	

	IF OBJECT_ID('tempdb..#GradReferenceTable',N'U') IS NOT NULL
		DROP TABLE #GradReferenceTable


	CREATE TABLE #GradReferenceTable (
		Selector NVARCHAR(200),
		SchoolId INT,
		StudentGroup NVARCHAR(100),
		GradRequirement NVARCHAR(100),
		Department NVARCHAR(100),
		GradeNineQuarterOneCreditValue DECIMAL(4,2),
		GradeNineQuarterTwoCreditValue DECIMAL(4,2),
		GradeNineQuarterThreeCreditValue DECIMAL(4,2),
		GradeNineQuarterFourCreditValue DECIMAL(4,2),
		GradeTenQuarterOneCreditValue DECIMAL(4,2),
		GradeTenQuarterTwoCreditValue DECIMAL(4,2),
		GradeTenQuarterThreeCreditValue DECIMAL(4,2),
		GradeTenQuarterFourCreditValue DECIMAL(4,2),
		GradeElevenQuarterOneCreditValue DECIMAL(4,2),
		GradeElevenQuarterTwoCreditValue DECIMAL(4,2),
		GradeElevenQuarterThreeCreditValue DECIMAL(4,2),
		GradeElevenQuarterFourCreditValue DECIMAL(4,2),
		GradeTwelveQuarterOneCreditValue DECIMAL(4,2),	
		GradeTwelveQuarterTwoCreditValue DECIMAL(4,2),
		GradeTwelveQuarterThreeCreditValue DECIMAL(4,2),
		GradeTwelveQuarterFourCreditValue DECIMAL(4,2)
	)

	DECLARE 
		@SelectorSchoolId INT,
		@SelectorStudentGroupId INT,
		@Selector NVARCHAR(200),
		@SelectorDepartmentId INT,
		@GradRequirementId INT,
		@SchoolId INT,
		@StudentGroup NVARCHAR(100),
		@GradRequirement NVARCHAR(100),
		@Department NVARCHAR(100),
		@GradeNineQuarterOneCreditValue DECIMAL(4,2),
		@GradeNineQuarterTwoCreditValue DECIMAL(4,2),
		@GradeNineQuarterThreeCreditValue DECIMAL(4,2),
		@GradeNineQuarterFourCreditValue DECIMAL(4,2),
		@GradeTenQuarterOneCreditValue DECIMAL(4,2),
		@GradeTenQuarterTwoCreditValue DECIMAL(4,2),
		@GradeTenQuarterThreeCreditValue DECIMAL(4,2),
		@GradeTenQuarterFourCreditValue DECIMAL(4,2),
		@GradeElevenQuarterOneCreditValue DECIMAL(4,2),
		@GradeElevenQuarterTwoCreditValue DECIMAL(4,2),
		@GradeElevenQuarterThreeCreditValue DECIMAL(4,2),
		@GradeElevenQuarterFourCreditValue DECIMAL(4,2),
		@GradeTwelveQuarterOneCreditValue DECIMAL(4,2),	
		@GradeTwelveQuarterTwoCreditValue DECIMAL(4,2),
		@GradeTwelveQuarterThreeCreditValue DECIMAL(4,2),
		@GradeTwelveQuarterFourCreditValue DECIMAL(4,2),	
		@Q1Id INT = (SELECT GradRequirementGradingPeriodId 
					FROM gradCredits.GradRequirementGradingPeriod WHERE GradRequirementGradingPeriod = 'QTR 1'),
		@Q2Id INT = (SELECT GradRequirementGradingPeriodId 
					FROM gradCredits.GradRequirementGradingPeriod WHERE GradRequirementGradingPeriod = 'QTR 2'),
		@Q3Id INT = (SELECT GradRequirementGradingPeriodId 
					FROM gradCredits.GradRequirementGradingPeriod WHERE GradRequirementGradingPeriod = 'QTR 3'),
		@Q4Id INT = (SELECT GradRequirementGradingPeriodId 
					FROM gradCredits.GradRequirementGradingPeriod WHERE GradRequirementGradingPeriod = 'QTR 4'),
		@GL9Id INT = (SELECT GradRequirementGradeLevelId 
					FROM gradCredits.GradRequirementGradeLevel WHERE GradRequirementGradeLevel = 9),
		@GL10Id INT = (SELECT GradRequirementGradeLevelId 
					FROM gradCredits.GradRequirementGradeLevel WHERE GradRequirementGradeLevel = 10),
		@GL11Id INT = (SELECT GradRequirementGradeLevelId 
					FROM gradCredits.GradRequirementGradeLevel WHERE GradRequirementGradeLevel = 11),
		@GL12Id INT = (SELECT GradRequirementGradeLevelId 
					FROM gradCredits.GradRequirementGradeLevel WHERE GradRequirementGradeLevel = 12),
		@validationError BIT = 0,
		@ErrorCount INT = 0,
		@ErrorMessage NVARCHAR(500) = '',		
		@SelectorId INT,
		@GradReferenceId INT,
		@BulkInsertRefQuery NVARCHAR(1000) = 'BULK INSERT #GradReferenceTable 
		FROM ''' + @FILE_NAME + ''' 
		WITH
		(
			FIRSTROW = 2,
			FIELDTERMINATOR = '','',
			ROWTERMINATOR = ''\n''
		)'
	CREATE TABLE #GradReqRecordsTable (
		GradRequirementSelectorId INT, 
		GradRequirementId INT, 
		GradRequirementGradeLevelId INT, 
		GradRequirementGradingPeriodId INT, 
		GradRequirementDepartmentId INT, 
		CreditValue DECIMAL(4,2))

	EXEC (@BulkInsertRefQuery);

	DECLARE cf_cursor CURSOR STATIC FOR
	SELECT *
	FROM #GradReferenceTable

	OPEN cf_cursor
	FETCH NEXT FROM cf_cursor
	INTO @Selector,
		@SchoolId,
		@StudentGroup,
		@GradRequirement, 
		@Department,
		@GradeNineQuarterOneCreditValue,
		@GradeNineQuarterTwoCreditValue,
		@GradeNineQuarterThreeCreditValue,
		@GradeNineQuarterFourCreditValue,
		@GradeTenQuarterOneCreditValue,
		@GradeTenQuarterTwoCreditValue,
		@GradeTenQuarterThreeCreditValue,
		@GradeTenQuarterFourCreditValue,
		@GradeElevenQuarterOneCreditValue,
		@GradeElevenQuarterTwoCreditValue,
		@GradeElevenQuarterThreeCreditValue,
		@GradeElevenQuarterFourCreditValue,
		@GradeTwelveQuarterOneCreditValue,	
		@GradeTwelveQuarterTwoCreditValue,
		@GradeTwelveQuarterThreeCreditValue,
		@GradeTwelveQuarterFourCreditValue

	WHILE @@FETCH_STATUS = 0
		BEGIN
			/** Validation for SELECTOR **/
			BEGIN TRY
				IF @Selector NOT IN (SELECT GradRequirementSchoolName FROM gradCredits.GradRequirementSchool)
				BEGIN
					SET @ErrorCount += 1
					SET @ErrorMessage += CHAR(10) +  'SELECTOR Validation Failed' + CHAR(9) + ' Invalid Selector value was provided in File. Valid Selectors are DISTRICT and SCHOOL'
				END	
	
			END TRY

			BEGIN CATCH
				SET @ErrorMessage += CHAR(10) + ERROR_MESSAGE() + CHAR(9) + ' on Line ' + CAST(ERROR_LINE() as varchar(10))
			END CATCH

			/** Validation for SCHOOL **/
			BEGIN TRY
				SELECT @SelectorSchoolId = GradRequirementSchoolId
				FROM gradCredits.GradRequirementSchool
				WHERE GradRequirementSchoolId = @SchoolId

				IF @@ROWCOUNT = 0
					BEGIN
						SET @SelectorSchoolId = -1;
						SET @ErrorCount += 1;
						SET @ErrorMessage += CHAR(10) +  'SCHOOLID Validation Failed' + CHAR(9) + ' Invalid SchoolId value(s) was provided in File. Valid SchoolIDs are loaded in gradCredits.GradRequirementSchool'
					END	

				ELSE IF @@ROWCOUNT > 1
					BEGIN
						SET @SelectorSchoolId = -1;
						SET @ErrorCount += 1;
						SET @ErrorMessage += CHAR(10) +  'SCHOOLID Validation Failed' + CHAR(9) + 'Multiple SchoolIDs found for ' + CAST(@SchoolId as varchar(10))
					END	
	
			END TRY

			BEGIN CATCH
				SET @ErrorMessage += CHAR(10) + ERROR_MESSAGE() + CHAR(9) + ' on Line ' + CAST(ERROR_LINE() as varchar(10))
			END CATCH

			/** Validation for StudentGroup **/
			BEGIN TRY
				IF @StudentGroup IS NOT NULL
					EXEC gradCredits.GetGradRequirementStudentGroupId @StudentGroup, @SelectorStudentGroupId OUTPUT
			END TRY

			BEGIN CATCH
				SET @ErrorMessage += CHAR(10) + ERROR_MESSAGE() + CHAR(9) + ' on Line ' + CAST(ERROR_LINE() as varchar(10))
			END CATCH


			/** Validation for SelectorId  **/
			BEGIN TRY		
				EXEC gradCredits.GetGradRequirementSelectorId 
						@Selector, @SelectorSchoolId, @SelectorStudentGroupId, @SelectorId OUTPUT				

				IF @SelectorId = -1				
					BEGIN
						SET @ErrorCount += 1
						SET @ErrorMessage += CHAR(10) + 'SELECTOR_ID Validation Failed' + CHAR(9) + 'Selector_ID was not found.'
					END
			END TRY

			BEGIN CATCH
				SET @ErrorMessage += CHAR(10) + ERROR_MESSAGE() + CHAR(9) + ' on Line ' + CAST(ERROR_LINE() as varchar(10))
			END CATCH


			/** Validation for GradRequirement  **/
			BEGIN TRY		
				EXEC gradCredits.GetGradRequirementId @GradRequirement, @GradRequirementId OUTPUT	

				IF @GradRequirementId = -1				
					BEGIN
						SET @ErrorCount += 1
						SET @ErrorMessage += CHAR(10) + 'GradRequirement Validation Failed' + CHAR(9) + 'GradRequirementId was not found.'
					END
			END TRY

			BEGIN CATCH
				SET @ErrorCount += 1
				SET @ErrorMessage += CHAR(10) + ERROR_MESSAGE() + CHAR(9) + ' on Line ' + CAST(ERROR_LINE() as varchar(10))
			END CATCH

			/** Validation for GradRequirementDepartment  **/
			BEGIN TRY		
				EXEC gradCredits.GetGradRequirementDepartmentId @Department,  @SelectorDepartmentId OUTPUT				

				IF @SelectorDepartmentId = -1				
					BEGIN
						SET @ErrorCount += 1
						SET @ErrorMessage += CHAR(10) + 'DepartmentID Validation Failed' + CHAR(9) + 'DepartmentID was not found.'
					END
			END TRY

			BEGIN CATCH
				SET @ErrorCount += 1
				SET @ErrorMessage += CHAR(10) + ERROR_MESSAGE() + CHAR(9) + ' on Line ' + CAST(ERROR_LINE() as varchar(10))
			END CATCH

			BEGIN TRY
				;WITH GradRequirementRecords AS (
					SELECT @SelectorId GradRequirementSelectorId, 
						@GradRequirementId GradRequirementId,
						@GL9Id GradRequirementGradeLevelId,
						@Q1Id GradRequirementGradingPeriodId,
						@SelectorDepartmentId GradRequirementDepartmentId,
						@GradeNineQuarterOneCreditValue CreditValue
					UNION ALL
					SELECT @SelectorId, @GradRequirementId,@GL9Id,@Q2Id,@SelectorDepartmentId,@GradeNineQuarterTwoCreditValue
					UNION ALL
					SELECT @SelectorId, @GradRequirementId,@GL9Id,@Q3Id,@SelectorDepartmentId,@GradeNineQuarterThreeCreditValue
					UNION ALL
					SELECT @SelectorId, @GradRequirementId,@GL9Id,@Q4Id,@SelectorDepartmentId,@GradeNineQuarterFourCreditValue
					UNION ALL
					SELECT @SelectorId, @GradRequirementId,@GL10Id,@Q1Id,@SelectorDepartmentId,@GradeTenQuarterOneCreditValue
					UNION ALL
					SELECT @SelectorId, @GradRequirementId,@GL10Id,@Q2Id,@SelectorDepartmentId,@GradeTenQuarterTwoCreditValue
					UNION ALL
					SELECT @SelectorId, @GradRequirementId,@GL10Id,@Q3Id,@SelectorDepartmentId,@GradeTenQuarterThreeCreditValue
					UNION ALL
					SELECT @SelectorId, @GradRequirementId,@GL10Id,@Q4Id,@SelectorDepartmentId,@GradeTenQuarterFourCreditValue
					UNION ALL
					SELECT @SelectorId, @GradRequirementId,@GL11Id,@Q1Id,@SelectorDepartmentId,@GradeElevenQuarterOneCreditValue
					UNION ALL
					SELECT @SelectorId, @GradRequirementId,@GL11Id,@Q2Id,@SelectorDepartmentId,@GradeElevenQuarterTwoCreditValue
					UNION ALL
					SELECT @SelectorId, @GradRequirementId,@GL11Id,@Q3Id,@SelectorDepartmentId,@GradeElevenQuarterThreeCreditValue
					UNION ALL
					SELECT @SelectorId, @GradRequirementId,@GL11Id,@Q4Id,@SelectorDepartmentId,@GradeElevenQuarterFourCreditValue
					UNION ALL
					SELECT @SelectorId, @GradRequirementId,@GL12Id,@Q1Id,@SelectorDepartmentId,@GradeTwelveQuarterOneCreditValue
					UNION ALL
					SELECT @SelectorId, @GradRequirementId,@GL12Id,@Q2Id,@SelectorDepartmentId,@GradeTwelveQuarterTwoCreditValue
					UNION ALL
					SELECT @SelectorId, @GradRequirementId,@GL12Id,@Q3Id,@SelectorDepartmentId,@GradeTwelveQuarterThreeCreditValue
					UNION ALL
					SELECT @SelectorId, @GradRequirementId,@GL12Id,@Q4Id,@SelectorDepartmentId,@GradeTwelveQuarterFourCreditValue
				)
				INSERT INTO #GradReqRecordsTable
				SELECT * FROM GradRequirementRecords

			END TRY

			BEGIN CATCH
				SET @ErrorCount += 1
				SET @ErrorMessage += CHAR(10) + ERROR_MESSAGE() + CHAR(9) + ' on Line ' + CAST(ERROR_LINE() as varchar(10))
			END CATCH

			FETCH NEXT FROM cf_cursor
			INTO @Selector,
				@SchoolId,
				@StudentGroup,
				@GradRequirement, 
				@Department,
				@GradeNineQuarterOneCreditValue,
				@GradeNineQuarterTwoCreditValue,
				@GradeNineQuarterThreeCreditValue,
				@GradeNineQuarterFourCreditValue,
				@GradeTenQuarterOneCreditValue,
				@GradeTenQuarterTwoCreditValue,
				@GradeTenQuarterThreeCreditValue,
				@GradeTenQuarterFourCreditValue,
				@GradeElevenQuarterOneCreditValue,
				@GradeElevenQuarterTwoCreditValue,
				@GradeElevenQuarterThreeCreditValue,
				@GradeElevenQuarterFourCreditValue,
				@GradeTwelveQuarterOneCreditValue,	
				@GradeTwelveQuarterTwoCreditValue,
				@GradeTwelveQuarterThreeCreditValue,
				@GradeTwelveQuarterFourCreditValue

		END

	CLOSE cf_cursor  
	DEALLOCATE cf_cursor

	BEGIN TRY
		IF @ErrorCount > 0
			THROW 51000, @ErrorMessage, 1;
		ELSE BEGIN
			BEGIN TRANSACTION
				DELETE FROM gradCredits.GradRequirementReference;

				--DBCC CHECKIDENT ('gradCredits.GradRequirementReference', RESEED, 0)

				INSERT INTO gradCredits.GradRequirementReference
				SELECT * FROM #GradReqRecordsTable
				WHERE GradRequirementSelectorId IS NOT NULL

				COMMIT TRANSACTION
		END			
	END TRY

	BEGIN CATCH
		IF @@TRANCOUNT > 0
			ROLLBACK TRANSACTION;
		THROW;
	END CATCH

GO



/****	LoadCourseSequence	***/
IF OBJECT_ID('gradCredits.LoadCourseSequence', 'P') IS NOT NULL
    DROP PROCEDURE gradCredits.LoadCourseSequence
GO

CREATE PROCEDURE gradCredits.LoadCourseSequence

	@FILE_NAME NVARCHAR(300) NULL	

AS

SET NOCOUNT ON

	IF @FILE_NAME IS NULL 
		SET @FILE_NAME = 'C:\GraduationCreditsImplementation\CourseSequenceTemplate.csv'
	

	IF OBJECT_ID('tempdb..#CourseSequenceTemplate',N'U') IS NOT NULL
		DROP TABLE #CourseSequenceTemplate


	CREATE TABLE #CourseSequenceTemplate(
		CourseCode nvarchar(25), 
		CourseTitle nvarchar(100), 
		SchoolYear nvarchar(10), 
		Duration nvarchar(10), 
		Department nvarchar(100), 
		CreditValue decimal(6,3), 
		SpecificGradRequirement nvarchar(100), 
		FirstSequenceGradRequirement nvarchar(100), 
		SecondSequenceGradRequirement nvarchar(100), 
		ThirdSequenceGradRequirement nvarchar(100),
		FourthSequenceGradRequirement nvarchar(100)
	)

	DECLARE 
		@DepartmentId int,
		@GradRequirementCourseSequenceId int,
		@SpecificGradReqId int,
		@FirstGradReqId int,
		@SecondGradReqId int,
		@ThirdGradReqId int,
		@FourthGradReqId int,
		@CourseCode nvarchar(25), 
		@CourseTitle nvarchar(100), 
		@SchoolYear nvarchar(10), 
		@Duration nvarchar(10), 
		@Department nvarchar(100), 
		@CreditValue decimal(6,3), 
		@SpecificGradRequirement nvarchar(100), 
		@FirstSequenceGradRequirement nvarchar(100), 
		@SecondSequenceGradRequirement nvarchar(100), 
		@ThirdSequenceGradRequirement nvarchar(100),
		@FourthSequenceGradRequirement nvarchar(100),
		@ErrorCount int,
		@ErrorMessage nvarchar(max) = '',
		@BulkInsertRefQuery NVARCHAR(1000) = 'BULK INSERT #CourseSequenceTemplate 
		FROM ''' + @FILE_NAME + ''' 
		WITH
		(
			FIRSTROW = 2,
			FIELDTERMINATOR = '','',
			ROWTERMINATOR = ''\n''
		)'

	EXEC (@BulkInsertRefQuery);

	DECLARE cf_cursor CURSOR STATIC FOR
		SELECT CourseCode, CourseTitle, SchoolYear, Duration, Department, CreditValue, SpecificGradRequirement, 
			FirstSequenceGradRequirement, SecondSequenceGradRequirement, ThirdSequenceGradRequirement, FourthSequenceGradRequirement
		FROM #CourseSequenceTemplate
		GROUP BY  CourseCode, CourseTitle, SchoolYear, Duration, Department, CreditValue, SpecificGradRequirement, 
			FirstSequenceGradRequirement, SecondSequenceGradRequirement, ThirdSequenceGradRequirement, FourthSequenceGradRequirement

	OPEN cf_cursor
	FETCH NEXT FROM cf_cursor
	INTO @CourseCode, 
		@CourseTitle, 
		@SchoolYear, 
		@Duration, 
		@Department, 
		@CreditValue, 
		@SpecificGradRequirement, 
		@FirstSequenceGradRequirement, 
		@SecondSequenceGradRequirement, 
		@ThirdSequenceGradRequirement,
		@FourthSequenceGradRequirement

	WHILE @@FETCH_STATUS = 0
		BEGIN
			
			/** Validation for GradRequirementDepartment  **/
			BEGIN TRY		
				EXEC gradCredits.GetGradRequirementDepartmentId @Department,  @DepartmentId OUTPUT				

				IF @DepartmentId = -1				
					BEGIN
						SET @ErrorCount += 1
						SET @ErrorMessage += CHAR(10) + 'DepartmentID Validation Failed' + CHAR(9) + 'DepartmentID was not found.'
					END
			END TRY

			BEGIN CATCH
				SET @ErrorCount += 1
				SET @ErrorMessage += CHAR(10) + ERROR_MESSAGE() + CHAR(9) + ' on Line ' + CAST(ERROR_LINE() as varchar(10))
			END CATCH


			/** Validation for Specific GradRequirement  **/
			BEGIN TRY	
				IF @SpecificGradRequirement IS NULL BEGIN
					SET @ErrorCount += 1
					SET @ErrorMessage += CHAR(10) + 'GradRequirement Validation Failed' + CHAR(9) + 
							'Specific GradRequirement was not set for ' + @CourseCode + ' - ' + @CourseTitle + ' - ' + @SchoolYear
				END
				ELSE BEGIN		
					EXEC gradCredits.GetGradRequirementId @SpecificGradRequirement, @SpecificGradReqId OUTPUT	

					IF @SpecificGradReqId = -1				
						BEGIN
							SET @ErrorCount += 1
							SET @ErrorMessage += CHAR(10) + 'GradRequirement Validation Failed' + CHAR(9) + 'GradRequirementId was not found.'
						END
				END
			END TRY

			BEGIN CATCH
				SET @ErrorCount += 1
				SET @ErrorMessage += CHAR(10) + ERROR_MESSAGE() + CHAR(9) + ' on Line ' + CAST(ERROR_LINE() as varchar(10))
			END CATCH

			/** Validation for First GradRequirement  **/
			BEGIN TRY
				IF @FirstSequenceGradRequirement IS NULL
					SET @FirstGradReqId = NULL
				ELSE BEGIN					
					EXEC gradCredits.GetGradRequirementId @FirstSequenceGradRequirement, @FirstGradReqId OUTPUT	

					IF @FirstGradReqId = -1				
						BEGIN
							SET @ErrorCount += 1
							SET @ErrorMessage += CHAR(10) + 'GradRequirement Validation Failed' + CHAR(9) + 'GradRequirementId was not found.'
						END
				END
			END TRY

			BEGIN CATCH
				SET @ErrorCount += 1
				SET @ErrorMessage += CHAR(10) + ERROR_MESSAGE() + CHAR(9) + ' on Line ' + CAST(ERROR_LINE() as varchar(10))
			END CATCH

			
			/** Validation for Second GradRequirement  **/
			BEGIN TRY	
				IF @SecondSequenceGradRequirement IS NULL
					SET @SecondGradReqId = NULL
				ELSE BEGIN			
					EXEC gradCredits.GetGradRequirementId @SecondSequenceGradRequirement, @SecondGradReqId OUTPUT	

					IF @SecondGradReqId = -1				
						BEGIN
							SET @ErrorCount += 1
							SET @ErrorMessage += CHAR(10) + 'GradRequirement Validation Failed' + CHAR(9) + 'GradRequirementId was not found.'
						END
				END
			END TRY

			BEGIN CATCH
				SET @ErrorCount += 1
				SET @ErrorMessage += CHAR(10) + ERROR_MESSAGE() + CHAR(9) + ' on Line ' + CAST(ERROR_LINE() as varchar(10))
			END CATCH


			/** Validation for Third GradRequirement  **/
			BEGIN TRY
				IF @ThirdSequenceGradRequirement IS NULL
					SET @ThirdGradReqId = NULL
				ELSE BEGIN		
					EXEC gradCredits.GetGradRequirementId @ThirdSequenceGradRequirement, @ThirdGradReqId OUTPUT	

					IF @ThirdGradReqId = -1				
						BEGIN
							SET @ErrorCount += 1
							SET @ErrorMessage += CHAR(10) + 'GradRequirement Validation Failed' + CHAR(9) + 'GradRequirementId was not found.'
						END
				END
			END TRY

			BEGIN CATCH
				SET @ErrorCount += 1
				SET @ErrorMessage += CHAR(10) + ERROR_MESSAGE() + CHAR(9) + ' on Line ' + CAST(ERROR_LINE() as varchar(10))
			END CATCH


			/** Validation for Fourth GradRequirement  **/
			BEGIN TRY	
				IF @FourthSequenceGradRequirement IS NULL
					SET @FourthGradReqId = NULL
				ELSE BEGIN
					EXEC gradCredits.GetGradRequirementId @FourthSequenceGradRequirement, @FourthGradReqId OUTPUT	

					IF @FourthGradReqId = -1				
						BEGIN
							SET @ErrorCount += 1
							SET @ErrorMessage += CHAR(10) + 'GradRequirement Validation Failed' + CHAR(9) + 'GradRequirementId was not found.'
						END
				END
			END TRY

			BEGIN CATCH
				SET @ErrorCount += 1
				SET @ErrorMessage += CHAR(10) + ERROR_MESSAGE() + CHAR(9) + ' on Line ' + CAST(ERROR_LINE() as varchar(10))
			END CATCH

			BEGIN TRY
				IF @SpecificGradRequirement IS NOT NULL BEGIN
					
					SELECT @GradRequirementCourseSequenceId = GradRequirementCourseSequenceId 
					FROM gradCredits.GradRequirementCourseSequence
					WHERE CourseCode = @CourseCode AND SchoolYear = @SchoolYear

					IF @@ROWCOUNT = 0
						INSERT INTO gradCredits.GradRequirementCourseSequence
						SELECT @CourseCode, @CourseTitle, @SchoolYear, @Duration, @DepartmentId, @CreditValue,
							@SpecificGradReqId, @FirstGradReqId, @SecondGradReqId, @ThirdGradReqId, @FourthGradReqId
					ELSE IF @@ROWCOUNT = 1
						UPDATE gradCredits.GradRequirementCourseSequence
						SET CourseTitle = @CourseTitle,
							Duration = @Duration,
							GradRequirementDepartmentId = @DepartmentId,
							CreditValue = @CreditValue,
							SpecificGradRequirementId = @SpecificGradReqId,
							FirstSequenceGradRequirementId = @FirstGradReqId,
							SecondSequenceGradRequirementId = @SecondGradReqId,
							ThirdSequenceGradRequirementId = @ThirdGradReqId,
							FourthSequenceGradRequirementId = @FourthGradReqId
						WHERE GradRequirementCourseSequenceId = @GradRequirementCourseSequenceId
					ELSE 
						SET @ErrorCount += 1
						SET @ErrorMessage += CHAR(10) + ERROR_MESSAGE() + CHAR(9) + ' on Line ' + CAST(ERROR_LINE() as varchar(10))
				END
			END TRY

			BEGIN CATCH
				SET @ErrorCount += 1
				SET @ErrorMessage += CHAR(10) + ERROR_MESSAGE() + CHAR(9) + ' on Line ' + CAST(ERROR_LINE() as varchar(10))
			END CATCH


			FETCH NEXT FROM cf_cursor
			INTO @CourseCode, 
				@CourseTitle, 
				@SchoolYear, 
				@Duration, 
				@Department, 
				@CreditValue, 
				@SpecificGradRequirement, 
				@FirstSequenceGradRequirement, 
				@SecondSequenceGradRequirement, 
				@ThirdSequenceGradRequirement,
				@FourthSequenceGradRequirement
		END
	CLOSE cf_cursor  
	DEALLOCATE cf_cursor


	UPDATE grsg
	SET GradRequirementCourseSequenceId = grcs.GradRequirementCourseSequenceId
	FROM gradCredits.GradRequirementStudentGrade grsg
	INNER JOIN gradCredits.GradRequirementStudentSchoolAssociation ssa
		ON ssa.GradRequirementStudentSchoolAssociationId = grsg.GradRequirementStudentSchoolAssociationId
	LEFT JOIN gradCredits.GradRequirementCourseSequence grcs
		ON SUBSTRING(grsg.DisplayCourseCode, 1,(IIF(CHARINDEX('Q',grsg.DisplayCourseCode) > 0, 
		CHARINDEX('Q',grsg.DisplayCourseCode)-1,LEN(grsg.DisplayCourseCode)))) = grcs.CourseCode
		AND grcs.SchoolYear = ssa.SchoolYear

GO




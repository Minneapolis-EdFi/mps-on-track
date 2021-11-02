/********************************************************			VIEWS			***************************************************************************************/


IF OBJECT_ID('gradCredits.CoursesWithoutSequence',N'V') IS NOT NULL
	DROP VIEW gradCredits.CoursesWithoutSequence
GO

CREATE VIEW gradCredits.CoursesWithoutSequence

AS

	SELECT CourseCode, SchoolYear, SampleCourseTitle1, SampleCourseTitle2, SampleGradeId1, SampleGradeId2
	FROM
		(
	SELECT SUBSTRING(g.DisplayCourseCode, 1,(IIF(CHARINDEX('Q',g.DisplayCourseCode) > 0, 
		CHARINDEX('Q',g.DisplayCourseCode)-1,LEN(g.DisplayCourseCode)))) CourseCode,
			MIN(CourseTitle) SampleCourseTitle1, MAX(CourseTitle) SampleCourseTitle2,
			ssa.SchoolYear, MIN(g.GradRequirementStudentGradeId) SampleGradeId1, MAX(g.GradRequirementStudentGradeId) SampleGradeId2
		FROM gradCredits.GradRequirementStudentGrade g
			INNER JOIN gradCredits.GradRequirementStudentSchoolAssociation ssa
			ON g.GradRequirementStudentSchoolAssociationId = ssa.GradRequirementStudentSchoolAssociationId
		WHERE GradRequirementCourseSequenceId IS NULL
		GROUP BY 
		SUBSTRING(g.DisplayCourseCode, 1,(IIF(CHARINDEX('Q',g.DisplayCourseCode) > 0, 
		CHARINDEX('Q',g.DisplayCourseCode)-1,LEN(g.DisplayCourseCode)))), SchoolYear	
) a
GO




/********************************************************			FUNCTIONS			***************************************************************************************/


/****	GetStudentChartData	***/
IF OBJECT_ID('gradCredits.GetStudentChartData', 'TF') IS NOT NULL
    DROP FUNCTION gradCredits.GetStudentChartData
GO



CREATE FUNCTION gradCredits.GetStudentChartData 
	(@StudentId INT)
RETURNS 
	@StudentChartData TABLE (
							StudentUniqueId INT,
							StudentName NVARCHAR(500),
							LastGradedGradingPeriod NVARCHAR(20),
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
		(SELECT CONCAT(CAST(MAX(SchoolYear) as varchar(10)),' - ',grgp.GradRequirementGradingPeriod)
		FROM gradCredits.GradRequirementStudentCreditGrade cg
			JOIN gradCredits.GradRequirementStudentGrade g
			on cg.GradRequirementStudentGradeId = g.GradRequirementStudentGradeId
			JOIN gradCredits.GradRequirementStudentSchoolAssociation ssa
			on g.GradRequirementStudentSchoolAssociationId = ssa.GradRequirementStudentSchoolAssociationId
		WHERE GradRequirementGradeLevelId = grs.CurrentGradeLevelId
			AND cg.GradRequirementStudentId = grs.GradRequirementStudentId)
		GradRequirementGradingPeriod,
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
	SchoolYearWhenTaken VARCHAR(10),
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
	DisplayOrder INT,
	GradRequirementDisplayOrder INT
						)

AS
	BEGIN

	INSERT INTO @StudentChartDataGrades
	SELECT
		StudentUniqueId,
		StudentName,
		CurrentGradeLevel,
		LastGradedQuarter,
		GradRequirement,
		GradRequirementGroup,
		ISNULL(CourseDetails, 'N/A') CourseDetails,
		ISNULL(GradeDetails, 'N/A') GradeDetails,
		ISNULL(CreditsContributedByCourse, 0.000) CreditsContributedByCourse,
		ISNULL(CourseCreditsReported, 0.000) CourseCreditsReported,
		LetterGradeEarned,
		GradingPeriod,
		WhenTakenGradeLevel,
		ISNULL(CAST(SchoolYearWhenTaken AS varchar(10)), 'N/A'),
		Term,
		IIF(CourseDetails IS NULL, 'Not Yet Taken', Status) Status,
		EarnedGradCredits,
		RemainingCreditsRequiredByLastGradedQuarter,
		RemainingCreditsRequiredByEndOfCurrentGradeLevel,
		RemainingCreditsRequiredByGraduation,
		DifferentialRemainingCreditsRequiredByGraduation,
		TotalEarnedCredits,
		TotalEarnedGradCredits,
		CreditValueRequired,
		CreditValueRemaining,
		CreditDeficiencyStatus,
		ROW_NUMBER() OVER (ORDER BY SchoolYearWhenTaken ASC, CASE TERM WHEN 'Fall' THEN 0 WHEN 'Spring' THEN 1 WHEN 'Summer' THEN 2 WHEN NULL THEN 3 END) DisplayOrder,
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
				WHEN GradRequirement = 'N/A' THEN 20 
				END GradRequirementDisplayOrder
	FROM
		(						SELECT StudentUniqueId,
				CONCAT('[',grs.StudentChartId,'] ', grs.StudentName) StudentName,
				grgll.GradRequirementGradeLevelDescription CurrentGradeLevel,
				LastGradedQuarter,
				gr.GradRequirement,
				GradRequirementDepartment GradRequirementGroup,
				NULLIF(REPLACE(CONCAT(DisplayCourseCode, ': ', CourseTitle,' [Sequence: ', grcs.CourseCode, ' ', 
				ISNULL(SpecificGradRequirement,'N/A'),' ', ISNULL(FirstSequenceGradRequirement,''), ' ',
				ISNULL(SecondSequenceGradRequirement, ''), ' ', ISNULL(ThirdSequenceGradRequirement,' '), ' ', 
				ISNULL(FourthSequenceGradRequirement,''),']', ' [Earned Credit: ' + 
				CAST(grsg.EarnedCredits as varchar(10)) + ']'),'  ',''),':[Sequence:N/A ]') CourseDetails,
				NULLIF(CONCAT(Term,' ', grssa.SchoolYear, ': ', grgl.GradRequirementGradeLevelDescription, ': ',grsh.GradRequirementSchoolName),' : : ') GradeDetails,
				CreditsContributed CreditsContributedByCourse,
				grsg.EarnedCredits CourseCreditsReported,
				LetterGradeEarned,
				grgp.GradRequirementGradingPeriod GradingPeriod,
				grgl.GradRequirementGradeLevelDescription WhenTakenGradeLevel,
				grssa.SchoolYear SchoolYearWhenTaken,
				Term,
				CASE WHEN PassingGradeIndicator = 1 THEN 'Passed'
				ELSE 'Not Passed' END Status,
				grsc.EarnedCredits EarnedGradCredits,
				grsc.RemainingCreditsRequiredByLastGradedQuarter,
				grsc.RemainingCreditsRequiredByEndOfCurrentGradeLevel,
				grsc.RemainingCreditsRequiredByGraduation,
				grsc.DifferentialRemainingCreditsRequiredByGraduation,
				grsc.TotalEarnedCredits,
				grsc.TotalEarnedGradCredits,
				grsc.CreditValueRequired,
				grsc.CreditValueRemaining,
				grsc.CreditDeficiencyStatus
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

		UNION ALL

			SELECT StudentUniqueId,
				CONCAT('[',grs.StudentChartId,'] ', grs.StudentName),
				grgll.GradRequirementGradeLevelDescription CurrentGradeLevel,
				LastGradedQuarter,
				'N/A' GradRequirement,
				'N/A' GradRequirementGroup,
				CONCAT(DisplayCourseCode, ': ', CourseTitle, ' [Sequence: N/A] [Earned Credit: ' , CAST(grsg.EarnedCredits as varchar(10)) , ']'),
				NULLIF(CONCAT(Term,' ', grssa.SchoolYear, ': ', grgl.GradRequirementGradeLevelDescription, ': ',grsh.GradRequirementSchoolName),' : : ') GradeDetails,
				grsg.EarnedCredits CreditsContributed,
				grsg.EarnedCredits CourseCredits,
				LetterGradeEarned,
				grgp.GradRequirementGradingPeriod,
				grgl.GradRequirementGradeLevelDescription,
				grssa.SchoolYear,
				Term,
				'Sequence Not Found' Status,
				0.000 EarnedCredits,
				0.000 RemainingCreditsRequiredByLastGradedQuarter,
				0.000 RemainingCreditsRequiredByEndOfCurrentGradeLevel,
				0.000 RemainingCreditsRequiredByGraduation,
				0.000 DifferentialRemainingCreditsRequiredByGraduation,
				0.000 TotalEarnedCredits,
				0.000 TotalEarnedGradCredits,
				0.000 CreditValueRequired,
				0.000 CreditValueRemaining,
				'N/A' CreditDeficiencyStatus
			FROM gradCredits.GradRequirementStudentGrade grsg
				LEFT JOIN gradCredits.GradRequirementStudent grs
				on grsg.GradRequirementStudentId = grs.GradRequirementStudentId
				LEFT JOIN gradCredits.GradRequirementGradeLevel grgll
				on grs.CurrentGradeLevelId = grgll.GradRequirementGradeLevelId
				LEFT JOIN gradCredits.GradRequirementStudentSchoolAssociation grssa
				on grsg.GradRequirementStudentSchoolAssociationId = grssa.GradRequirementStudentSchoolAssociationId
				LEFT JOIN gradCredits.GradRequirementSchool grsh
				on grssa.GradRequirementSchoolId = grsh.GradRequirementSchoolId
				LEFT JOIN gradCredits.GradRequirementGradeLevel grgl
				on grssa.GradRequirementGradeLevelId = grgl.GradRequirementGradeLevelId
				LEFT JOIN gradCredits.GradRequirementGradingPeriod grgp
				on grsg.GradRequirementGradingPeriodId = grgp.GradRequirementGradingPeriodId
				LEFT JOIN
				(
				SELECT gc.GradRequirementStudentId,
					GradRequirementGradingPeriod LastGradedQuarter
				FROM gradCredits.GradRequirementStudentCredit gc
					INNER JOIN gradCredits.GradRequirementGradingPeriod gp
					ON gc.LastGradedGradingPeriodId = gp.GradRequirementGradingPeriodId
				GROUP BY gc.GradRequirementStudentId, GradRequirementGradingPeriod			
			) lgq
				ON lgq.GradRequirementStudentId = grsg.GradRequirementStudentId
			WHERE GradRequirementCourseSequenceId IS NULL
				AND grs.StudentUniqueId = @StudentId
		) a


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
	@StudentData TABLE (
						StudentUniqueId INT,
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
		(SELECT CONCAT(CAST(MAX(SchoolYear) as varchar(10)),' - ',LastGradedQuarter)
		FROM gradCredits.GradRequirementStudentCreditGrade cg
			JOIN gradCredits.GradRequirementStudentGrade g
			on cg.GradRequirementStudentGradeId = g.GradRequirementStudentGradeId
			JOIN gradCredits.GradRequirementStudentSchoolAssociation ssa
			on g.GradRequirementStudentSchoolAssociationId = ssa.GradRequirementStudentSchoolAssociationId
		WHERE GradRequirementGradeLevelId = grs.CurrentGradeLevelId
			AND cg.GradRequirementStudentId = grs.GradRequirementStudentId)
			GradRequirementGradingPeriod,
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


/********************************************************			STORED PROCEDURES			***************************************************************************************/


/****	GetGradRequirementSchoolId	***/
IF OBJECT_ID('gradCredits.GetExecutionLogId', 'P') IS NOT NULL
    DROP PROCEDURE gradCredits.GetExecutionLogId
GO


CREATE PROCEDURE [gradCredits].[GetExecutionLogId]

	@ProcName NVARCHAR(100),
	@ExecStart DATETIME,
	@ExecId INT OUTPUT

AS

BEGIN
	SET NOCOUNT ON

	IF @ProcName IS NOT NULL
		AND @ExecStart IS NOT NULL
		AND NOT EXISTS
		(
			SELECT 1
		FROM gradCredits.GradRequirementExecutionLog
		WHERE GradRequirementStoredProcedure = @ProcName
			AND ExecutionStart = @ExecStart
		)
		BEGIN
		INSERT INTO gradCredits.GradRequirementExecutionLog
			(GradRequirementStoredProcedure, ExecutionStart)
		SELECT @ProcName, @ExecStart
	END

	SET @ExecId = COALESCE((SELECT GradRequirementExecutionLogId
			FROM gradCredits.GradRequirementExecutionLog
			WHERE GradRequirementStoredProcedure = @ProcName
			AND ExecutionStart = @ExecStart),-1)
END
GO





/****	GetExecutionLogDetailId	***/
IF OBJECT_ID('gradCredits.GetExecutionLogDetailId', 'P') IS NOT NULL
    DROP PROCEDURE gradCredits.GetExecutionLogDetailId
GO



CREATE PROCEDURE [gradCredits].[GetExecutionLogDetailId]

	@TableName NVARCHAR(100),
	@ExecId INT,
	@LogDetailId INT OUTPUT

AS

BEGIN
	SET NOCOUNT ON

	IF @TableName IS NOT NULL
		AND @ExecId IN (SELECT GradRequirementExecutionLogId
		FROM gradCredits.GradRequirementExecutionLog)
		AND NOT EXISTS
		(
			SELECT 1
		FROM gradCredits.GradRequirementExecutionLogDetail
		WHERE GradRequirementExecutionLogId = @ExecId
			AND GradRequirementTable = @TableName
		)
		BEGIN
		INSERT INTO gradCredits.GradRequirementExecutionLogDetail
			(GradRequirementExecutionLogId, GradRequirementTable)
		SELECT @ExecId, @TableName
	END

	SET @LogDetailId = COALESCE((SELECT GradRequirementExecutionLogDetailId
			FROM gradCredits.GradRequirementExecutionLogDetail
			WHERE GradRequirementExecutionLogId = @ExecId
			AND GradRequirementTable = @TableName),-1)
END
GO





/****	LogAudit	***/
IF OBJECT_ID('gradCredits.LogAudit', 'P') IS NOT NULL
    DROP PROCEDURE gradCredits.LogAudit
GO


CREATE PROCEDURE [gradCredits].[LogAudit]

	@ExecutionLogDetailId INT,
	@Message NVARCHAR(max)

AS

BEGIN
	SET NOCOUNT ON

	INSERT INTO gradCredits.GradRequirementExecutionLogAudits
	SELECT @ExecutionLogDetailId, @Message
END
GO



/****	GetGradRequirementGradeLevelId	***/
IF OBJECT_ID('gradCredits.GetGradRequirementGradeLevelId', 'P') IS NOT NULL
    DROP PROCEDURE gradCredits.GetGradRequirementGradeLevelId
GO

CREATE PROCEDURE gradCredits.GetGradRequirementGradeLevelId
	@ExecutionLogId INT,
	@ExecutionLogDetailId INT,
	@GradeLevelDescription NVARCHAR(200),
	@GradeLevel INT,
	@GradRequirementGradeLevelId INT OUTPUT
AS
IF @GradeLevel IS NOT NULL
	AND NOT EXISTS
	(
		SELECT 1
	FROM gradCredits.GradRequirementGradeLevel
	WHERE GradRequirementGradeLevel = @GradeLevel
		AND GradRequirementGradeLevelDescription = @GradeLevelDescription
	) 
	BEGIN
	INSERT INTO gradCredits.GradRequirementGradeLevel
	SELECT @GradeLevel, @GradeLevelDescription

	UPDATE gradCredits.GradRequirementExecutionLogDetail
		SET RecordsInserted = ISNULL(RecordsInserted,0) + 1
		WHERE GradRequirementExecutionLogDetailId = @ExecutionLogDetailId
		AND GradRequirementExecutionLogId = @ExecutionLogId
		AND GradRequirementTable = 'GradRequirementGradeLevel'
END

SET @GradRequirementGradeLevelId = COALESCE((SELECT GradRequirementGradeLevelId
		FROM gradCredits.GradRequirementGradeLevel
		WHERE GradRequirementGradeLevel = @GradeLevel
			AND GradRequirementGradeLevelDescription = @GradeLevelDescription),-1)	
GO




/****	GetGradRequirementGradingPeriodId	***/
IF OBJECT_ID('gradCredits.GetGradRequirementGradingPeriodId', 'P') IS NOT NULL
    DROP PROCEDURE gradCredits.GetGradRequirementGradingPeriodId
GO

CREATE PROCEDURE gradCredits.GetGradRequirementGradingPeriodId
	@ExecutionLogId INT,
	@ExecutionLogDetailId INT,
	@GradingPeriod NVARCHAR(200),
	@GradRequirementGradingPeriodId INT OUTPUT
AS
IF @GradingPeriod IS NOT NULL
	AND NOT EXISTS
	(
		SELECT 1
	FROM gradCredits.GradRequirementGradingPeriod
	WHERE GradRequirementGradingPeriod = @GradingPeriod
	) 
	BEGIN
	INSERT INTO gradCredits.GradRequirementGradingPeriod
	SELECT @GradingPeriod

	UPDATE gradCredits.GradRequirementExecutionLogDetail
		SET RecordsInserted = ISNULL(RecordsInserted,0) + 1
		WHERE GradRequirementExecutionLogDetailId = @ExecutionLogDetailId
		AND GradRequirementExecutionLogId = @ExecutionLogId
		AND GradRequirementTable = 'GradRequirementGradingPeriod'
END

SET @GradRequirementGradingPeriodId = COALESCE((SELECT GradRequirementGradingPeriodId
		FROM gradCredits.GradRequirementGradingPeriod
		WHERE GradRequirementGradingPeriod = @GradingPeriod),-1)	
GO


/****	GetGradRequirementSchoolId	***/
IF OBJECT_ID('gradCredits.GetGradRequirementSchoolId', 'P') IS NOT NULL
    DROP PROCEDURE gradCredits.GetGradRequirementSchoolId
GO

CREATE PROCEDURE gradCredits.GetGradRequirementSchoolId
	@ExecutionLogId INT,
	@ExecutionLogDetailId INT,
	@SchoolName NVARCHAR(200),
	@SchoolId INT,
	@SelectorSchoolId INT OUTPUT
AS
IF @SchoolId IS NOT NULL
	AND NOT EXISTS
	(
		SELECT 1
	FROM gradCredits.GradRequirementSchool
	WHERE GradRequirementSchoolId = @SchoolId
		AND GradRequirementSchoolName = @SchoolName
	) 
	BEGIN
	INSERT INTO gradCredits.GradRequirementSchool
	SELECT @SchoolId, @SchoolName

	UPDATE gradCredits.GradRequirementExecutionLogDetail
		SET RecordsInserted = ISNULL(RecordsInserted,0) + 1
		WHERE GradRequirementExecutionLogDetailId = @ExecutionLogDetailId
		AND GradRequirementExecutionLogId = @ExecutionLogId
		AND GradRequirementTable = 'GradRequirementSchool'
END

SET @SelectorSchoolId = COALESCE((SELECT 1
		FROM gradCredits.GradRequirementSchool
		WHERE GradRequirementSchoolId = @SchoolId
			AND GradRequirementSchoolName = @SchoolName),-1)	
GO



/****	GetGradRequirementStudentGroupId	***/
IF OBJECT_ID('gradCredits.GetGradRequirementStudentGroupId', 'P') IS NOT NULL
    DROP PROCEDURE gradCredits.GetGradRequirementStudentGroupId
GO

CREATE PROCEDURE gradCredits.GetGradRequirementStudentGroupId
	@ExecutionLogId INT,
	@ExecutionLogDetailId INT,
	@StudentGroup NVARCHAR(100),
	@StudentGroupId INT OUTPUT
AS
--IF @StudentGroup IS NOT NULL
--	AND NOT EXISTS
--	(
--		SELECT 1
--	FROM gradCredits.GradRequirementStudentGroup
--	WHERE GradRequirementStudentGroup = @StudentGroup
--	) 
--	BEGIN
--	INSERT INTO gradCredits.GradRequirementStudentGroup
--	SELECT @StudentGroup

--	UPDATE gradCredits.GradRequirementExecutionLogDetail
--		SET RecordsInserted = ISNULL(RecordsInserted,0) + 1
--		WHERE GradRequirementExecutionLogDetailId = @ExecutionLogDetailId
--		AND GradRequirementExecutionLogId = @ExecutionLogId
--		AND GradRequirementTable = 'GradRequirementStudentGroup'
--END

SET @StudentGroupId = COALESCE((SELECT GradRequirementStudentGroupId
		FROM gradCredits.GradRequirementStudentGroup
		WHERE GradRequirementStudentGroupCode = @StudentGroup),-1)
GO




/****	GetGradRequirementSelectorId	***/
IF OBJECT_ID('gradCredits.GetGradRequirementSelectorId', 'P') IS NOT NULL
    DROP PROCEDURE gradCredits.GetGradRequirementSelectorId
GO


CREATE PROCEDURE gradCredits.GetGradRequirementSelectorId
	@ExecutionLogId INT,
	@ExecutionLogDetailId INT,
	@Selector NVARCHAR(50),
	@SchoolId INT,
	@StudentGroupId INT NULL,
	@SelectorId INT OUTPUT
AS
BEGIN

	IF @SchoolId IN (SELECT GradRequirementSchoolId
		FROM gradCredits.GradRequirementSchool)
		AND ((@StudentGroupId IN (SELECT GradRequirementStudentGroupId
		FROM gradCredits.GradRequirementStudentGroup)))
		AND @Selector IN (SELECT GradRequirementSchoolName
		FROM gradCredits.GradRequirementSchool)
			BEGIN
		SELECT @SelectorId = grs.GradRequirementSelectorId
		FROM gradCredits.GradRequirementSelector grs
		WHERE grs.GradRequirementSchoolId = @SchoolId
			AND COALESCE(grs.GradRequirementStudentGroupId,-9999) = COALESCE(@StudentGroupId,-9999)
			AND grs.GradRequirementSelector = @Selector

		IF @@ROWCOUNT = 0 
					BEGIN
			INSERT INTO gradCredits.GradRequirementSelector
				(GradRequirementSelector, GradRequirementSchoolId, GradRequirementStudentGroupId)
			SELECT @Selector, @SchoolId, @StudentGroupId

			SELECT @SelectorId = grs.GradRequirementSelectorId
			FROM gradCredits.GradRequirementSelector grs
			WHERE grs.GradRequirementSchoolId = @SchoolId
				AND COALESCE(grs.GradRequirementStudentGroupId,-9999) = COALESCE(@StudentGroupId,-9999)
				AND grs.GradRequirementSelector = @Selector

			UPDATE gradCredits.GradRequirementExecutionLogDetail
						SET RecordsInserted = ISNULL(RecordsInserted,0) + 1
						WHERE GradRequirementExecutionLogDetailId = @ExecutionLogDetailId
				AND GradRequirementExecutionLogId = @ExecutionLogId
				AND GradRequirementTable = 'GradRequirementSelector'
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
	@ExecutionLogId INT,
	@ExecutionLogDetailId INT,
	@GradRequirement NVARCHAR(200),
	@GradRequirementId INT OUTPUT
AS
BEGIN

	IF @GradRequirement = 'Elective' 
			SET @GradRequirement = 'Electives'
	IF @GradRequirement = 'Government' 
			SET @GradRequirement = 'Government and Citizenship'

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


		UPDATE gradCredits.GradRequirementExecutionLogDetail
			SET RecordsInserted = ISNULL(RecordsInserted,0) + 1
			WHERE GradRequirementExecutionLogDetailId = @ExecutionLogDetailId
			AND GradRequirementExecutionLogId = @ExecutionLogId
			AND GradRequirementTable = 'GradRequirement'
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
	@ExecutionLogId INT,
	@ExecutionLogDetailId INT,
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

		UPDATE gradCredits.GradRequirementExecutionLogDetail
			SET RecordsInserted = ISNULL(RecordsInserted,0) + 1
			WHERE GradRequirementExecutionLogDetailId = @ExecutionLogDetailId
			AND GradRequirementExecutionLogId = @ExecutionLogId
			AND GradRequirementTable = 'GradRequirementDepartment'
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

DECLARE 
		@ProcName NVARCHAR(100) = 'LoadGradReference',
		@ExecStart DATETIME = GETDATE(),
		@ExecutionLogId INT

EXEC gradCredits.GetExecutionLogId @ProcName, @ExecStart, @ExecutionLogId OUTPUT

IF @FILE_NAME IS NULL 
		SET @FILE_NAME = 'C:\GraduationCreditsImplementation\GraduationPathTemplate.csv'


IF OBJECT_ID('tempdb..#GradReferenceTable',N'U') IS NOT NULL
		DROP TABLE #GradReferenceTable


CREATE TABLE #GradReferenceTable
(
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
		@GradRequirementSchoolLogDetailId INT,
		@GradRequirementStudentGroupLogDetailId INT,
		@GradReferenceLogDetailId INT,
		@GradRequirementLogDetailId INT,
		@GradRequirementDepartmentLDId INT,
		@GradRequirementSelectorDetailId INT,
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
		@GradRequirementGradeLevelLogDetailId INT,
		@GradRequirementGradingPeriodLogDetailId INT,
		@Q1Id INT,
		@Q2Id INT,
		@Q3Id INT,
		@Q4Id INT,
		@GL9Id INT,
		@GL10Id INT,
		@GL11Id INT,
		@GL12Id INT,
		@validationError BIT = 0,
		@ErrorCount INT = 0,
		@ErrorMessage NVARCHAR(500) = '',		
		@SelectorId INT,
		@GradReferenceId INT,
		@RecordsAuditedCount INT = 0,
		@GradRefInsertedCount INT,
		@BulkInsertRefQuery NVARCHAR(1000) = 'BULK INSERT #GradReferenceTable 
		FROM ''' + @FILE_NAME + ''' 
		WITH
		(
			FIRSTROW = 2,
			FIELDTERMINATOR = '','',
			ROWTERMINATOR = ''\n''
		)'
CREATE TABLE #GradReqRecordsTable
(
	GradRequirementSelectorId INT,
	GradRequirementId INT,
	GradRequirementGradeLevelId INT,
	GradRequirementGradingPeriodId INT,
	GradRequirementDepartmentId INT,
	CreditValue DECIMAL(4,2)
)

EXEC (@BulkInsertRefQuery);

EXEC gradCredits.GetExecutionLogDetailId 'GradRequirementGradeLevel', @ExecutionLogId, @GradRequirementGradeLevelLogDetailId OUTPUT
EXEC gradCredits.GetGradRequirementGradeLevelId @ExecutionLogId, @GradRequirementGradeLevelLogDetailId, 'Ninth grade', 9, @GL9Id OUTPUT
EXEC gradCredits.GetGradRequirementGradeLevelId @ExecutionLogId, @GradRequirementGradeLevelLogDetailId, 'Tenth grade', 10, @GL10Id OUTPUT
EXEC gradCredits.GetGradRequirementGradeLevelId @ExecutionLogId, @GradRequirementGradeLevelLogDetailId, 'Eleventh grade', 11, @GL11Id OUTPUT
EXEC gradCredits.GetGradRequirementGradeLevelId @ExecutionLogId, @GradRequirementGradeLevelLogDetailId, 'Twelfth grade', 12, @GL12Id OUTPUT


EXEC gradCredits.GetExecutionLogDetailId 'GradRequirementGradingPeriod', @ExecutionLogId, @GradRequirementGradingPeriodLogDetailId OUTPUT
EXEC gradCredits.GetGradRequirementGradingPeriodId @ExecutionLogId, @GradRequirementGradingPeriodLogDetailId, 'QTR 1', @Q1Id OUTPUT
EXEC gradCredits.GetGradRequirementGradingPeriodId @ExecutionLogId, @GradRequirementGradingPeriodLogDetailId, 'QTR 2', @Q2Id OUTPUT
EXEC gradCredits.GetGradRequirementGradingPeriodId @ExecutionLogId, @GradRequirementGradingPeriodLogDetailId, 'QTR 3', @Q3Id OUTPUT
EXEC gradCredits.GetGradRequirementGradingPeriodId @ExecutionLogId, @GradRequirementGradingPeriodLogDetailId, 'QTR 4', @Q4Id OUTPUT


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
	/** Validation for SCHOOL **/
	BEGIN TRY
				EXEC gradCredits.GetExecutionLogDetailId 'GradRequirementSchool', @ExecutionLogId,
					@GradRequirementSchoolLogDetailId OUTPUT
					
				IF @Selector IS NOT NULL BEGIN
		EXEC gradCredits.GetGradRequirementSchoolId
						@ExecutionLogId, @GradRequirementSchoolLogDetailId, 
						@Selector,  @SchoolId, @SelectorSchoolId OUTPUT

		IF @SelectorSchoolId = -1				
						BEGIN
			SET @ErrorMessage = CONCAT('Validation for GradRequirementSchool failed: ', ERROR_MESSAGE(), 'GradRequirementSchool: ', COALESCE(@Selector,'NULL; SchoolId: '), COALESCE(@SchoolId, 'NULL'))

			EXEC gradCredits.LogAudit @GradRequirementSchoolLogDetailId, @ErrorMessage

			SET @RecordsAuditedCount = @RecordsAuditedCount + 1
		END
	END	
			END TRY

			BEGIN CATCH
				SET @ErrorMessage = CONCAT('Validation for GradRequirementSchool failed: ', ERROR_MESSAGE(), 'GradRequirementSchool: ', COALESCE(@Selector,'NULL; SchoolId: '), COALESCE(@SchoolId, 'NULL'))

				EXEC gradCredits.LogAudit @GradRequirementSchoolLogDetailId, @ErrorMessage

				SET @RecordsAuditedCount = @RecordsAuditedCount + 1
			END CATCH


	/** Validation for StudentGroup **/
	BEGIN TRY
				EXEC gradCredits.GetExecutionLogDetailId 'GradRequirementStudentGroup', @ExecutionLogId,
					@GradRequirementStudentGroupLogDetailId OUTPUT

				IF @StudentGroup IS NOT NULL
					EXEC gradCredits.GetGradRequirementStudentGroupId @ExecutionLogId,
						@GradRequirementStudentGroupLogDetailId, @StudentGroup, @SelectorStudentGroupId OUTPUT
			END TRY

			BEGIN CATCH
				SET @ErrorMessage = CONCAT('Validation for GradRequirementGroup failed: ', ERROR_MESSAGE(), 'GradRequirementStudentGroup: ', COALESCE(@StudentGroup,'NULL'))

				EXEC gradCredits.LogAudit @GradRequirementStudentGroupLogDetailId, @ErrorMessage

				SET @RecordsAuditedCount = @RecordsAuditedCount + 1
			END CATCH


	/** Validation for SelectorId  **/
	BEGIN TRY	
				EXEC gradCredits.GetExecutionLogDetailId 'GradRequirementSelector', @ExecutionLogId,
					@GradRequirementSelectorDetailId OUTPUT
	
				EXEC gradCredits.GetGradRequirementSelectorId @ExecutionLogId,
					@GradRequirementSelectorDetailId, @Selector, @SchoolId, 
					@SelectorStudentGroupId, @SelectorId OUTPUT				

				IF @SelectorId = -1				
					BEGIN
		SET @ErrorMessage = CONCAT('Validation for GradRequirementSelector failed: ', ERROR_MESSAGE())

		EXEC gradCredits.LogAudit @GradRequirementSelectorDetailId, @ErrorMessage

		SET @RecordsAuditedCount = @RecordsAuditedCount + 1
	END
			END TRY

			BEGIN CATCH
				SET @ErrorMessage = CONCAT('Validation for GradRequirementSelector failed: ', ERROR_MESSAGE())

				EXEC gradCredits.LogAudit @GradRequirementSelectorDetailId, @ErrorMessage

				SET @RecordsAuditedCount = @RecordsAuditedCount + 1
			END CATCH


	/** Validation for GradRequirement  **/
	BEGIN TRY
				EXEC gradCredits.GetExecutionLogDetailId 'GradRequirement', @ExecutionLogId,
					@GradRequirementLogDetailId OUTPUT
						
				IF @GradRequirement IS NULL BEGIN
		SET @ErrorMessage = CONCAT('GradRequirement IS NULL: ', ERROR_MESSAGE())

		EXEC gradCredits.LogAudit @GradRequirementLogDetailId, @ErrorMessage
		SET @RecordsAuditedCount = @RecordsAuditedCount + 1
	END
				ELSE BEGIN
		EXEC gradCredits.GetGradRequirementId 
						@ExecutionLogId, @GradRequirementLogDetailId, @GradRequirement, @GradRequirementId OUTPUT

		IF @GradRequirementId = -1				
						BEGIN
			SET @ErrorMessage = CONCAT('Validation for GradRequirement failed: ', ERROR_MESSAGE(),
							', GradRequirement: ', 	COALESCE(@GradRequirementId,'NULL'))

			EXEC gradCredits.LogAudit @GradRequirementLogDetailId, @ErrorMessage

			SET @RecordsAuditedCount = @RecordsAuditedCount + 1
		END
	END
			END TRY

			BEGIN CATCH
				SET @ErrorMessage = CONCAT('Validation for GradRequirement failed: ', ERROR_MESSAGE(),
							', GradRequirement: ', 	COALESCE(@GradRequirementId,'NULL'))

				EXEC gradCredits.LogAudit @GradRequirementLogDetailId, @ErrorMessage	

				SET @RecordsAuditedCount = @RecordsAuditedCount + 1
			END CATCH


	/** Validation for GradRequirementDepartment  **/
	BEGIN TRY		
				EXEC gradCredits.GetExecutionLogDetailId 'GradRequirementDepartment', @ExecutionLogId,
					@GradRequirementDepartmentLDId OUTPUT

				EXEC gradCredits.GetGradRequirementDepartmentId 
						@ExecutionLogId, @GradRequirementDepartmentLDId, @Department,  @SelectorDepartmentId OUTPUT			
				IF @SelectorDepartmentId = -1				
					BEGIN
		SET @ErrorMessage = CONCAT('Validation for GradRequirementDepartment failed: ', ERROR_MESSAGE(),	COALESCE(@Department,'NULL'))

		EXEC gradCredits.LogAudit @GradRequirementDepartmentLDId, @ErrorMessage

		SET @RecordsAuditedCount = @RecordsAuditedCount + 1
	END
			END TRY

			BEGIN CATCH
				SET @ErrorMessage = CONCAT('Validation for GradRequirementDepartment failed: ', ERROR_MESSAGE(),	COALESCE(@Department,'NULL'))

				EXEC gradCredits.LogAudit @GradRequirementDepartmentLDId, @ErrorMessage

				SET @RecordsAuditedCount = @RecordsAuditedCount + 1
			END CATCH


	BEGIN TRY
				;WITH
		GradRequirementRecords
		AS
		(
																																																	SELECT @SelectorId GradRequirementSelectorId,
					@GradRequirementId GradRequirementId,
					@GL9Id GradRequirementGradeLevelId,
					@Q1Id GradRequirementGradingPeriodId,
					@SelectorDepartmentId GradRequirementDepartmentId,
					@GradeNineQuarterOneCreditValue CreditValue
			UNION ALL
				SELECT @SelectorId, @GradRequirementId, @GL9Id, @Q2Id, @SelectorDepartmentId, @GradeNineQuarterTwoCreditValue
			UNION ALL
				SELECT @SelectorId, @GradRequirementId, @GL9Id, @Q3Id, @SelectorDepartmentId, @GradeNineQuarterThreeCreditValue
			UNION ALL
				SELECT @SelectorId, @GradRequirementId, @GL9Id, @Q4Id, @SelectorDepartmentId, @GradeNineQuarterFourCreditValue
			UNION ALL
				SELECT @SelectorId, @GradRequirementId, @GL10Id, @Q1Id, @SelectorDepartmentId, @GradeTenQuarterOneCreditValue
			UNION ALL
				SELECT @SelectorId, @GradRequirementId, @GL10Id, @Q2Id, @SelectorDepartmentId, @GradeTenQuarterTwoCreditValue
			UNION ALL
				SELECT @SelectorId, @GradRequirementId, @GL10Id, @Q3Id, @SelectorDepartmentId, @GradeTenQuarterThreeCreditValue
			UNION ALL
				SELECT @SelectorId, @GradRequirementId, @GL10Id, @Q4Id, @SelectorDepartmentId, @GradeTenQuarterFourCreditValue
			UNION ALL
				SELECT @SelectorId, @GradRequirementId, @GL11Id, @Q1Id, @SelectorDepartmentId, @GradeElevenQuarterOneCreditValue
			UNION ALL
				SELECT @SelectorId, @GradRequirementId, @GL11Id, @Q2Id, @SelectorDepartmentId, @GradeElevenQuarterTwoCreditValue
			UNION ALL
				SELECT @SelectorId, @GradRequirementId, @GL11Id, @Q3Id, @SelectorDepartmentId, @GradeElevenQuarterThreeCreditValue
			UNION ALL
				SELECT @SelectorId, @GradRequirementId, @GL11Id, @Q4Id, @SelectorDepartmentId, @GradeElevenQuarterFourCreditValue
			UNION ALL
				SELECT @SelectorId, @GradRequirementId, @GL12Id, @Q1Id, @SelectorDepartmentId, @GradeTwelveQuarterOneCreditValue
			UNION ALL
				SELECT @SelectorId, @GradRequirementId, @GL12Id, @Q2Id, @SelectorDepartmentId, @GradeTwelveQuarterTwoCreditValue
			UNION ALL
				SELECT @SelectorId, @GradRequirementId, @GL12Id, @Q3Id, @SelectorDepartmentId, @GradeTwelveQuarterThreeCreditValue
			UNION ALL
				SELECT @SelectorId, @GradRequirementId, @GL12Id, @Q4Id, @SelectorDepartmentId, @GradeTwelveQuarterFourCreditValue
		)
	INSERT INTO #GradReqRecordsTable
	SELECT *
	FROM GradRequirementRecords

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

	EXEC gradCredits.GetExecutionLogDetailId 'GradRequirementReference', 
							@ExecutionLogId, @GradReferenceLogDetailId OUTPUT

	INSERT INTO gradCredits.GradRequirementReference
	SELECT *
	FROM #GradReqRecordsTable
	WHERE GradRequirementSelectorId IS NOT NULL

	SET @GradRefInsertedCount = @@ROWCOUNT

	UPDATE gradCredits.GradRequirementExecutionLogDetail
				SET RecordsInserted = @GradRefInsertedCount,
					RecordsAudited = @RecordsAuditedCount
				WHERE GradRequirementExecutionLogDetailId = @GradReferenceLogDetailId
		AND GradRequirementExecutionLogId = @ExecutionLogId

	UPDATE gradCredits.GradRequirementExecutionLog
				SET ExecutionEnd = GETDATE(),
					ExecutionStatus = 'Success'
				WHERE GradRequirementExecutionLogId = @ExecutionLogId

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

DECLARE 
		@ProcName NVARCHAR(100) = 'LoadCourseSequence',
		@ExecStart DATETIME = GETDATE(),
		@ExecutionLogId INT

EXEC gradCredits.GetExecutionLogId @ProcName, @ExecStart, @ExecutionLogId OUTPUT

IF @FILE_NAME IS NULL 
		SET @FILE_NAME = 'C:\GraduationCreditsImplementation\CourseSequenceTemplate.csv'


IF OBJECT_ID('tempdb..#CourseSequenceTemplate',N'U') IS NOT NULL
		DROP TABLE #CourseSequenceTemplate


CREATE TABLE #CourseSequenceTemplate
(
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
		@ErrorMessage nvarchar(500) = '',
		@CourseSequenceDId int,
		@GradRequirementDepartmentLDId int,
		@SpecificGradRequirementDetailId int,
		@FirstSequenceGradRequirementDId int,
		@SecondSequenceGradRequirementDId int,
		@ThirdSequenceGradRequirementDId int,
		@FourthSequenceGradRequirementDId int, 
		@UpdatedStudentGradesCount int,
		@StudentGradeLogDetailId int,
		@RecordsAuditedCount int = 0,
		@CourseSeqInsertCount int = 0,
		@CourseSeqUpdateCount int = 0,
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
				EXEC gradCredits.GetExecutionLogDetailId 'GradRequirementDepartment', @ExecutionLogId,
					@GradRequirementDepartmentLDId OUTPUT
					
				IF @Department IS NULL
					SET @DepartmentId = NULL
				ELSE BEGIN
		EXEC gradCredits.GetGradRequirementDepartmentId 
						@ExecutionLogId, @GradRequirementDepartmentLDId, @Department,  @DepartmentId OUTPUT

		IF @DepartmentId = -1				
						BEGIN
			SET @ErrorMessage = CONCAT('Validation for GradRequirementDepartment failed: ', ERROR_MESSAGE(),
							', ', @CourseCode, ' - ', @CourseTitle, ' - ', @SchoolYear, 'GradRequirementDepartment: ',
							COALESCE(@Department,'NULL'))

			EXEC gradCredits.LogAudit @GradRequirementDepartmentLDId, @ErrorMessage

			SET @RecordsAuditedCount = @RecordsAuditedCount + 1
		END
	END
			END TRY

			BEGIN CATCH
				SET @ErrorMessage = CONCAT('Validation for GradRequirementDepartment failed: ', ERROR_MESSAGE(),
							', ', @CourseCode, ' - ', @CourseTitle, ' - ', @SchoolYear, 'GradRequirementDepartment: ',
							COALESCE(@Department,'NULL'))

				EXEC gradCredits.LogAudit @GradRequirementDepartmentLDId, @ErrorMessage
				SET @RecordsAuditedCount = @RecordsAuditedCount + 1
			END CATCH


	/** Validation for Specific GradRequirement  **/
	BEGIN TRY
				EXEC gradCredits.GetExecutionLogDetailId 'GradRequirement', @ExecutionLogId,
					@SpecificGradRequirementDetailId OUTPUT
						
				IF @SpecificGradRequirement IS NULL BEGIN
		SET @ErrorMessage = CONCAT('SpecificGradRequirement IS NULL: ', ERROR_MESSAGE(),
							', ', @CourseCode, ' - ', @CourseTitle, ' - ', @SchoolYear)

		EXEC gradCredits.LogAudit @SpecificGradRequirementDetailId, @ErrorMessage
		SET @RecordsAuditedCount = @RecordsAuditedCount + 1
	END
				ELSE BEGIN
		EXEC gradCredits.GetGradRequirementId 
						@ExecutionLogId, @SpecificGradRequirementDetailId, @SpecificGradRequirement, @SpecificGradReqId OUTPUT

		IF @SpecificGradReqId = -1				
						BEGIN
			SET @ErrorMessage = CONCAT('Validation for Specific GradRequirement failed: ', ERROR_MESSAGE(),
							', ', @CourseCode, ' - ', @CourseTitle, ' - ', @SchoolYear, 'SpecificSequenceGradRequirement: ',
							COALESCE(@SpecificGradRequirement,'NULL'))

			EXEC gradCredits.LogAudit @SpecificGradRequirementDetailId, @ErrorMessage
			SET @RecordsAuditedCount = @RecordsAuditedCount + 1
		END
	END
			END TRY

			BEGIN CATCH
				SET @ErrorMessage = CONCAT('Validation for Specific GradRequirement failed: ', ERROR_MESSAGE(),
							', ', @CourseCode, ' - ', @CourseTitle, ' - ', @SchoolYear, 'SpecificSequenceGradRequirement: ',
							COALESCE(@SpecificGradRequirement,'NULL'))

				EXEC gradCredits.LogAudit @SpecificGradRequirementDetailId, @ErrorMessage	
				SET @RecordsAuditedCount = @RecordsAuditedCount + 1
			END CATCH

	/** Validation for First GradRequirement  **/
	BEGIN TRY
				EXEC gradCredits.GetExecutionLogDetailId 'GradRequirement', @ExecutionLogId,
					@FirstSequenceGradRequirementDId OUTPUT
						
				IF @FirstSequenceGradRequirement IS NULL
					SET @FirstGradReqId = NULL
				ELSE BEGIN
		EXEC gradCredits.GetGradRequirementId 
						@ExecutionLogId, @FirstSequenceGradRequirementDId, @FirstSequenceGradRequirement, @FirstGradReqId OUTPUT

		IF @FirstGradReqId = -1				
						BEGIN
			SET @ErrorMessage = CONCAT('Validation for First GradRequirement failed: ', ERROR_MESSAGE(),
							', ', @CourseCode, ' - ', @CourseTitle, ' - ', @SchoolYear, 'FirstSequenceGradRequirement: ',
							COALESCE(@FirstSequenceGradRequirement,'NULL'))

			EXEC gradCredits.LogAudit @FirstSequenceGradRequirementDId, @ErrorMessage
			SET @RecordsAuditedCount = @RecordsAuditedCount + 1
		END
	END
			END TRY

			BEGIN CATCH
				SET @ErrorMessage = CONCAT('Validation for First GradRequirement failed: ', ERROR_MESSAGE(),
							', ', @CourseCode, ' - ', @CourseTitle, ' - ', @SchoolYear, 'FirstSequenceGradRequirement: ',
							COALESCE(@FirstSequenceGradRequirement,'NULL'))

				EXEC gradCredits.LogAudit @FirstSequenceGradRequirementDId, @ErrorMessage	
				SET @RecordsAuditedCount = @RecordsAuditedCount + 1
			END CATCH


	/** Validation for Second GradRequirement  **/
	BEGIN TRY					
				EXEC gradCredits.GetExecutionLogDetailId 'GradRequirement', @ExecutionLogId,
					@SecondSequenceGradRequirementDId OUTPUT
						
				IF @SecondSequenceGradRequirement IS NULL
					SET @SecondGradReqId = NULL
				ELSE BEGIN
		EXEC gradCredits.GetGradRequirementId 
						@ExecutionLogId, @SecondSequenceGradRequirementDId, @SecondSequenceGradRequirement, @SecondGradReqId OUTPUT

		IF @SecondGradReqId = -1				
						BEGIN
			SET @ErrorMessage = CONCAT('Validation for Second GradRequirement failed: ', ERROR_MESSAGE(),
							', ', @CourseCode, ' - ', @CourseTitle, ' - ', @SchoolYear, 'SecondSequenceGradRequirement: ',
							COALESCE(@SecondSequenceGradRequirement,'NULL'))

			EXEC gradCredits.LogAudit @SecondSequenceGradRequirementDId, @ErrorMessage
			SET @RecordsAuditedCount = @RecordsAuditedCount + 1
		END
	END
			END TRY

			BEGIN CATCH
				SET @ErrorMessage = CONCAT('Validation for Second GradRequirement failed: ', ERROR_MESSAGE(),
							', ', @CourseCode, ' - ', @CourseTitle, ' - ', @SchoolYear, 'SecondSequenceGradRequirement: ',
							COALESCE(@SecondSequenceGradRequirement,'NULL'))

				EXEC gradCredits.LogAudit @SecondSequenceGradRequirementDId, @ErrorMessage	
				SET @RecordsAuditedCount = @RecordsAuditedCount + 1
			END CATCH


	/** Validation for Third GradRequirement  **/
	BEGIN TRY
				EXEC gradCredits.GetExecutionLogDetailId 'GradRequirement', @ExecutionLogId,
					@ThirdSequenceGradRequirementDId OUTPUT
						
				IF @ThirdSequenceGradRequirement IS NULL
					SET @ThirdGradReqId = NULL
				ELSE BEGIN
		EXEC gradCredits.GetGradRequirementId 
						@ExecutionLogId, @ThirdSequenceGradRequirementDId, @ThirdSequenceGradRequirement, @ThirdGradReqId OUTPUT

		IF @ThirdGradReqId = -1				
						BEGIN
			SET @ErrorMessage = CONCAT('Validation for Third GradRequirement failed: ', ERROR_MESSAGE(),
							', ', @CourseCode, ' - ', @CourseTitle, ' - ', @SchoolYear, 'ThirdSequenceGradRequirement: ',
							COALESCE(@ThirdSequenceGradRequirement,'NULL'))

			EXEC gradCredits.LogAudit @ThirdSequenceGradRequirementDId, @ErrorMessage
			SET @RecordsAuditedCount = @RecordsAuditedCount + 1
		END
	END
			END TRY

			BEGIN CATCH
				SET @ErrorMessage = CONCAT('Validation for Third GradRequirement failed: ', ERROR_MESSAGE(),
							', ', @CourseCode, ' - ', @CourseTitle, ' - ', @SchoolYear, 'ThirdSequenceGradRequirement: ',
							COALESCE(@ThirdSequenceGradRequirement,'NULL'))

				EXEC gradCredits.LogAudit @ThirdSequenceGradRequirementDId, @ErrorMessage	
				SET @RecordsAuditedCount = @RecordsAuditedCount + 1
			END CATCH


	/** Validation for Fourth GradRequirement  **/
	BEGIN TRY					
				EXEC gradCredits.GetExecutionLogDetailId 'GradRequirement', @ExecutionLogId,
					@FourthSequenceGradRequirementDId OUTPUT						

				IF @FourthSequenceGradRequirement IS NULL
					SET @FourthGradReqId = NULL
				ELSE BEGIN
		EXEC gradCredits.GetGradRequirementId 
						@ExecutionLogId, @FourthSequenceGradRequirementDId, @FourthSequenceGradRequirement, @FourthGradReqId OUTPUT

		IF @FourthGradReqId = -1				
						BEGIN
			SET @ErrorMessage = CONCAT('Validation for Fourth GradRequirement failed: ', ERROR_MESSAGE(),
							', ', @CourseCode, ' - ', @CourseTitle, ' - ', @SchoolYear, 'FourthSequenceGradRequirement: ',
							COALESCE(@FourthSequenceGradRequirement,'NULL'))

			EXEC gradCredits.LogAudit @FourthSequenceGradRequirementDId, @ErrorMessage
			SET @RecordsAuditedCount = @RecordsAuditedCount + 1
		END
	END
			END TRY

			BEGIN CATCH
				SET @ErrorMessage = CONCAT('Validation for Fourth GradRequirement failed: ', ERROR_MESSAGE(),
							', ', @CourseCode, ' - ', @CourseTitle, ' - ', @SchoolYear, 'FourthSequenceGradRequirement: ',
							COALESCE(@FourthSequenceGradRequirement,'NULL'))

				EXEC gradCredits.LogAudit @FourthSequenceGradRequirementDId, @ErrorMessage	
				SET @RecordsAuditedCount = @RecordsAuditedCount + 1
			END CATCH

	SET @CreditValue = COALESCE(@CreditValue, 0.250)

	IF @SchoolYear IS NULL
				BEGIN
		SET @ErrorMessage = CONCAT('SchoolYear IS NULL: ', ERROR_MESSAGE(),
							', ', @CourseCode, ' - ', @CourseTitle, ' - ', COALESCE(@SpecificGradRequirement,'NULL'))

		EXEC gradCredits.LogAudit @SpecificGradRequirementDetailId, @ErrorMessage
		SET @RecordsAuditedCount = @RecordsAuditedCount + 1
	END


	BEGIN TRY	
				EXEC gradCredits.GetExecutionLogDetailId 'GradRequirementCourseSequence', 
							@ExecutionLogId, @CourseSequenceDId OUTPUT
										
				IF @SpecificGradRequirement IS NOT NULL AND @SchoolYear IS NOT NULL BEGIN

		SELECT @GradRequirementCourseSequenceId = GradRequirementCourseSequenceId
		FROM gradCredits.GradRequirementCourseSequence
		WHERE CourseCode = @CourseCode AND SchoolYear = @SchoolYear

		IF @@ROWCOUNT = 0 BEGIN

			INSERT INTO gradCredits.GradRequirementCourseSequence
			SELECT @CourseCode, @CourseTitle, @SchoolYear, @Duration, @DepartmentId, @CreditValue,
				@SpecificGradReqId, @FirstGradReqId, @SecondGradReqId, @ThirdGradReqId, @FourthGradReqId

			SET @CourseSeqInsertCount = @CourseSeqInsertCount + 1

		END ELSE IF @@ROWCOUNT = 1 BEGIN
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
				AND
				(
									CourseTitle <> @CourseTitle
				OR
				COALESCE(Duration,'@ERR') <> COALESCE(@Duration,'@ERR')
				OR
				COALESCE(GradRequirementDepartmentId,-9999) <> COALESCE(@DepartmentId,-9999)
				OR
				COALESCE(CreditValue,-9999) <> COALESCE(@CreditValue,-9999)
				OR
				COALESCE(SpecificGradRequirementId,-9999) <> COALESCE(@SpecificGradReqId,-9999)
				OR
				COALESCE(FirstSequenceGradRequirementId,-9999) <> COALESCE(@FirstGradReqId,-9999)
				OR
				COALESCE(SecondSequenceGradRequirementId,-9999) <> COALESCE(@SecondGradReqId,-9999)
				OR
				COALESCE(ThirdSequenceGradRequirementId,-9999) <> COALESCE(@ThirdGradReqId,-9999)
				OR
				COALESCE(FourthSequenceGradRequirementId,-9999) <> COALESCE(@FourthGradReqId,-9999)
								)
			SET @CourseSeqUpdateCount = @CourseSeqUpdateCount + 1
		END ELSE IF @@ROWCOUNT > 1 BEGIN
			SET @ErrorMessage = CONCAT('Update failed: Multiple records found for: ', 
							@CourseCode, ' - ', @CourseTitle, ' - ', @SchoolYear)

			EXEC gradCredits.LogAudit @CourseSequenceDId, @ErrorMessage
			SET @RecordsAuditedCount = @RecordsAuditedCount + 1
		END
	END
			END TRY

			BEGIN CATCH
				SET @ErrorMessage = CONCAT('Update failed: Unknown Error ', ERROR_MESSAGE(),
							', ', @CourseCode, ' - ', @CourseTitle, ' - ', @SchoolYear)

				EXEC gradCredits.LogAudit @CourseSequenceDId, @ErrorMessage	
				SET @RecordsAuditedCount = @RecordsAuditedCount + 1
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

UPDATE gradCredits.GradRequirementExecutionLogDetail
	SET RecordsInserted = @CourseSeqInsertCount,
		RecordsUpdated = @CourseSeqUpdateCount,
		RecordsAudited = @RecordsAuditedCount
	WHERE GradRequirementExecutionLogDetailId = @CourseSequenceDId
	AND GradRequirementExecutionLogId = @ExecutionLogId

EXEC gradCredits.GetExecutionLogDetailId 'GradRequirementStudentGrade', 
			@ExecutionLogId, @StudentGradeLogDetailId OUTPUT

UPDATE grsg
	SET GradRequirementCourseSequenceId = grcs.GradRequirementCourseSequenceId
	FROM gradCredits.GradRequirementStudentGrade grsg
	INNER JOIN gradCredits.GradRequirementStudentSchoolAssociation ssa
	ON ssa.GradRequirementStudentSchoolAssociationId = grsg.GradRequirementStudentSchoolAssociationId
	LEFT JOIN gradCredits.GradRequirementCourseSequence grcs
	ON SUBSTRING(grsg.DisplayCourseCode, 1,(IIF(CHARINDEX('Q',grsg.DisplayCourseCode) > 0, 
		CHARINDEX('Q',grsg.DisplayCourseCode)-1,LEN(grsg.DisplayCourseCode)))) = grcs.CourseCode
		AND grcs.SchoolYear = ssa.SchoolYear
	WHERE 
		SUBSTRING(grsg.DisplayCourseCode, 1,(IIF(CHARINDEX('Q',grsg.DisplayCourseCode) > 0, 
		CHARINDEX('Q',grsg.DisplayCourseCode)-1,LEN(grsg.DisplayCourseCode)))) = grcs.CourseCode
	AND grcs.SchoolYear = ssa.SchoolYear

SET @UpdatedStudentGradesCount = @@ROWCOUNT

UPDATE gradCredits.GradRequirementExecutionLogDetail
	SET RecordsUpdated = @UpdatedStudentGradesCount
	WHERE GradRequirementExecutionLogDetailId = @StudentGradeLogDetailId
	AND GradRequirementExecutionLogId = @ExecutionLogId

UPDATE gradCredits.GradRequirementExecutionLog
	SET ExecutionEnd = GETDATE(),
		ExecutionStatus = 'Success'
	WHERE GradRequirementExecutionLogId = @ExecutionLogId

GO




/****	UpdateStudentSelectors	***/
IF OBJECT_ID('gradCredits.UpdateStudentSelectors', 'P') IS NOT NULL
    DROP PROCEDURE gradCredits.UpdateStudentSelectors
GO

CREATE PROCEDURE gradCredits.UpdateStudentSelectors AS
BEGIN

SET NOCOUNT ON
	
	DECLARE 
		@ProcName NVARCHAR(100) = 'UpdateStudentSelectors',
		@ExecStart DATETIME = GETDATE(),
		@ExecutionLogId INT,
		@LogDetailOutput INT

	EXEC gradCredits.GetExecutionLogId @ProcName, @ExecStart, @ExecutionLogId OUTPUT

	DECLARE @UpdateSQL NVARCHAR(MAX),
		 @counter INT = 1

	/**	Reset all SelectorIDs in the GradRequirementStudent Table	***/
	UPDATE gradCredits.GradRequirementStudent
	SET GradRequirementSelectorId = NULL;

	/*** Define Ordering and build out Update Query Statement for all defined selectors	***/
	SELECT 
		ROW_NUMBER() OVER (ORDER BY s.GradRequirementSchoolId, 
			CASE WHEN CHARINDEX('_DEFAULT', GradRequirementStudentGroupCode) > 0 THEN 1 ELSE 0 END) Ordering,
		s.GradRequirementSelectorId, 
		s.GradRequirementSelector, 
		s.GradRequirementSchoolId,
		g.GradRequirementStudentGroupCode,
		g.GradRequirementStudentGroupDefinition,
		CONCAT('UPDATE gradCredits.GradRequirementStudent
	SET GradRequirementSelectorId = ', s.GradRequirementSelectorId, '
	WHERE GradRequirementStudentId IN (', g.GradRequirementStudentGroupDefinition , ');') UpdateStatement
	INTO #UpdateTable
	FROM gradCredits.GradRequirementSelector s
	INNER JOIN gradCredits.GradRequirementStudentGroup g
		ON s.GradRequirementStudentGroupId = g.GradRequirementStudentGroupId
	INNER JOIN gradCredits.GradRequirementReference r 
		ON s.GradRequirementSelectorId = r.GradRequirementSelectorId
	GROUP BY s.GradRequirementSelectorId, 
		s.GradRequirementSelector, 
		s.GradRequirementSchoolId,
		g.GradRequirementStudentGroupCode,
		g.GradRequirementStudentGroupDefinition

	WHILE @counter <= (SELECT MAX(Ordering) FROM #UpdateTable)
	BEGIN
		SET @UpdateSQL = (SELECT UpdateStatement FROM #UpdateTable WHERE Ordering = @counter)

		BEGIN TRY
			EXEC gradCredits.GetExecutionLogDetailId 'UpdateStudentSelectors', 
							@ExecutionLogId, @LogDetailOutput OUTPUT

			EXEC sp_executesql @UpdateSQL
		END TRY

		BEGIN CATCH

			DECLARE @ErrorMessage NVARCHAR(255) = ERROR_MESSAGE()
			EXEC gradCredits.LogAudit @LogDetailOutput, @ErrorMessage

		END CATCH
		SET @counter = @counter + 1
	END

	DROP TABLE #UpdateTable

	SET NOCOUNT OFF

END


/****	UpdateClassOfSchoolYear	***/
IF OBJECT_ID('gradCredits.UpdateClassOfSchoolYear', 'P') IS NOT NULL
    DROP PROCEDURE gradCredits.UpdateClassOfSchoolYear
GO

CREATE PROCEDURE gradCredits.UpdateClassOfSchoolYear AS
BEGIN

SET NOCOUNT ON

UPDATE gs
SET ClassOfSchoolYear = cosy.ClassOfSchoolYear
FROM gradCredits.GradRequirementStudent gs
INNER JOIN
(SELECT s.GradRequirementStudentId, l.GradRequirementGradeLevel,
	CASE GradRequirementGradeLevel 
		WHEN 9 THEN SchoolYear + 3
		WHEN 10 THEN SchoolYear + 2
		WHEN 11 THEN SchoolYear + 1
		WHEN 12 THEN SchoolYear END ClassOfSchoolYear
FROM gradCredits.GradRequirementStudent s
JOIN gradCredits.GradRequirementGradeLevel l on s.CurrentGradeLevelId = l.GradRequirementGradeLevelId
OUTER APPLY 
	(SELECT SchoolYear FROM gradCredits.GradRequirementSchoolYear WHERE CurrentSchoolYearIndicator = 1) sc
) cosy on gs.GradRequirementStudentId = cosy.GradRequirementStudentId

END
GO


/****	CreateStudentSelectorGroup	***/
IF OBJECT_ID('gradCredits.CreateStudentSelectorGroup', 'P') IS NOT NULL
    DROP PROCEDURE gradCredits.CreateStudentSelectorGroup
GO

CREATE PROCEDURE gradCredits.CreateStudentSelectorGroup 
	@StudentGroup NVARCHAR(100),
	@StudentGroupCode NVARCHAR(50),
	@StudentGroupDefinition NVARCHAR(MAX)
AS
BEGIN
/*** Example Usage
EXEC gradCredits.CreateStudentSelectorGroup
	@StudentGroup = 'Class of 2025 and Beyond Students Southwest High',
	@StudentGroupCode = 'SOUTHWEST_HIGH_COSY2025',
	@StudentGroupDefinition = 
'SELECT GradRequirementStudentId
FROM gradCredits.GradRequirementStudent 
WHERE GradRequirementSelectorId IS NULL
AND ClassOfSchoolYear >= 2025
AND GradPathSchoolId = 364'

**/
SET NOCOUNT ON

MERGE INTO gradCredits.GradRequirementStudentGroup AS TARGET
USING (SELECT @StudentGroup StudentGroup, @StudentGroupCode StudentGroupCode , @StudentGroupDefinition StudentGroupDefinition) AS SOURCE
ON TARGET.GradRequirementStudentGroup = SOURCE.StudentGroup
WHEN MATCHED AND 
	TARGET.GradRequirementStudentGroupCode <> SOURCE.StudentGroupCode
	OR TARGET.GradRequirementStudentGroupDefinition <> SOURCE.StudentGroupDefinition
THEN UPDATE SET
	TARGET.GradRequirementStudentGroupCode = SOURCE.StudentGroupCode,
	TARGET.GradRequirementStudentGroupDefinition = SOURCE.StudentGroupDefinition
WHEN NOT MATCHED THEN 
	INSERT (GradRequirementStudentGroup, GradRequirementStudentGroupCode, GradRequirementStudentGroupDefinition)
	VALUES (StudentGroup, StudentGroupCode, StudentGroupDefinition)
;

END

GO



/****	CreateStudentSelectorGroup	***/
IF OBJECT_ID('gradCredits.UpdateDemographicStudentGroup', 'P') IS NOT NULL
    DROP PROCEDURE gradCredits.UpdateDemographicStudentGroup
GO

CREATE PROCEDURE gradCredits.UpdateDemographicStudentGroup 
AS
BEGIN
/*** Example Usage
To update this script, add the demographic/student combo to the INSERT INTO @dgroup section
use a UNION ALL statement to combine groups
For eg. add the following after the 

	UNION ALL
	SELECT 'XX', 'A sample group', 1223455 as GradRequirementStudentId

**/
SET NOCOUNT ON

DECLARE @dgroup TABLE (GroupCode NVARCHAR(50), GroupDescription NVARCHAR(255), GradRequirementStudentId INT)

INSERT INTO @dgroup
--This section adds a group of all SPED students district-wide
SELECT 'SPED_DISTRICTWIDE' GroupCode, 'All Special Education Students Districtwide' GroupDescription, gs.GradRequirementStudentId
FROM Mnpls3_EdFi_Ods_2022.edfi.StudentSpecialEducationProgramAssociation sp
INNER JOIN Mnpls3_EdFi_Ods_2022.edfi.Student s on sp.StudentUSI = s.StudentUSI
INNER JOIN gradCredits.GradRequirementStudent gs ON s.StudentUniqueId = gs.StudentUniqueId


MERGE INTO gradCredits.GradRequirementDemographicGroup AS TARGET
USING (SELECT DISTINCT GroupCode, GroupDescription FROM @dgroup) AS SOURCE
ON TARGET.DemographicGroupCode = SOURCE.GroupCode
WHEN MATCHED AND 
	TARGET.DemographicGroupDescription <> SOURCE.GroupDescription
THEN UPDATE SET
	TARGET.DemographicGroupDescription = SOURCE.GroupDescription
WHEN NOT MATCHED THEN 
	INSERT (DemographicGroupCode, DemographicGroupDescription)
	VALUES (GroupCode, GroupDescription)
;


MERGE INTO gradCredits.GradRequirementDemographicStudentGroup AS TARGET
USING (SELECT DISTINCT gp.DemographicId, g.GradRequirementStudentId 
		FROM @dgroup g
		INNER JOIN gradCredits.GradRequirementDemographicGroup gp 
		ON g.GroupCode = gp.DemographicGroupCode 
		INNER JOIN gradCredits.GradRequirementStudent gs
		ON g.GradRequirementStudentId = gs.GradRequirementStudentId) AS SOURCE
ON TARGET.DemographicId = SOURCE.DemographicId
AND TARGET.GradRequirementStudentId = SOURCE.GradRequirementStudentId
WHEN NOT MATCHED THEN 
	INSERT (DemographicId, GradRequirementStudentId)
	VALUES (DemographicId, GradRequirementStudentId)
WHEN NOT MATCHED BY SOURCE
	THEN DELETE
;

SET NOCOUNT OFF

END

GO



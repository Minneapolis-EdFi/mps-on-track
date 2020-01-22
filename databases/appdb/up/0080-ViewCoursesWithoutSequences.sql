IF OBJECT_ID('gradCredits.CoursesWithoutSequence',N'V') IS NOT NULL
	DROP VIEW gradCredits.CoursesWithoutSequence
GO

CREATE VIEW gradCredits.CoursesWithoutSequence

AS

SELECT CourseCode, CourseTitle, SchoolYear
FROM 
(
	SELECT SUBSTRING(g.DisplayCourseCode, 1,(IIF(CHARINDEX('Q',g.DisplayCourseCode) > 0, 
		CHARINDEX('Q',g.DisplayCourseCode)-1,LEN(g.DisplayCourseCode)))) CourseCode,
		ROW_NUMBER() OVER (PARTITION BY (SUBSTRING(g.DisplayCourseCode, 1,(IIF(CHARINDEX('Q',g.DisplayCourseCode) > 0, 
		CHARINDEX('Q',g.DisplayCourseCode)-1,LEN(g.DisplayCourseCode))))) ORDER BY CourseTitle) rn, CourseTitle,
		ssa.SchoolYear
	FROM gradCredits.GradRequirementStudentGrade g
	INNER JOIN gradCredits.GradRequirementStudentSchoolAssociation ssa
		ON g.GradRequirementStudentSchoolAssociationId = ssa.GradRequirementStudentSchoolAssociationId
	WHERE GradRequirementCourseSequenceId IS NULL
	GROUP BY 
		SUBSTRING(g.DisplayCourseCode, 1,(IIF(CHARINDEX('Q',g.DisplayCourseCode) > 0, 
		CHARINDEX('Q',g.DisplayCourseCode)-1,LEN(g.DisplayCourseCode)))), SchoolYear, CourseTitle	
) a
WHERE rn = 1

/****	RefreshGradComputation	***/
IF OBJECT_ID('gradCredits.RefreshGradComputation', 'P') IS NOT NULL
    DROP PROCEDURE gradCredits.RefreshGradComputation
GO

CREATE PROCEDURE gradCredits.RefreshGradComputation

AS

BEGIN
	SET NOCOUNT ON

	DECLARE 
		@ProcName NVARCHAR(100) = 'RefreshGradComputation',
		@ExecStart DATETIME = GETDATE(),
		@ExecutionLogId INT,
		@AlterDropConstraintsLogDetailId INT,
		@AlterAddConstraintsLogDetailId INT,
		@GradesReferenceSequenceLogDetailId INT,
		@ErrorMessage NVARCHAR(MAX)

	EXEC gradCredits.GetExecutionLogId @ProcName, @ExecStart, @ExecutionLogId OUTPUT


	BEGIN TRY
		EXEC gradCredits.GetExecutionLogDetailId 'AlterDropConstraints', @ExecutionLogId,
					@AlterDropConstraintsLogDetailId OUTPUT

		ALTER TABLE gradCredits.GradRequirementStudentSchoolAssociation
		DROP CONSTRAINT FK_GRADREQ_SCHID 

		ALTER TABLE  gradCredits.GradRequirementStudentGrade
		DROP CONSTRAINT FK_GRADREQ_SSAID 

		ALTER TABLE gradCredits.GradRequirementStudentCreditGrade
		DROP CONSTRAINT FK_GRADREQSC_SCGID 
	END TRY

	BEGIN CATCH
		SET @ErrorMessage =  CAST(ERROR_MESSAGE() as varchar(max))
		EXEC gradCredits.LogAudit @AlterDropConstraintsLogDetailId, @ErrorMessage
	END CATCH


	BEGIN TRY
		EXEC gradCredits.GetExecutionLogDetailId 'GradesReferenceSequenceLoad', @ExecutionLogId,
					@GradesReferenceSequenceLogDetailId OUTPUT

		EXEC gradCredits.LoadGrades NULL, NULL

		EXEC gradCredits.UpdateClassOfSchoolYear

		EXEC gradCredits.UpdateDemographicStudentGroup

		EXEC gradCredits.UpdateStudentSelectors

		EXEC gradCredits.LoadCourseSequence NULL

		EXEC gradCredits.LoadGradReference NULL

		EXEC gradCredits.ComputeGradCredits
	END TRY

	BEGIN CATCH
		SET @ErrorMessage =  CAST(ERROR_MESSAGE() as varchar(max))
		EXEC gradCredits.LogAudit @GradesReferenceSequenceLogDetailId, @ErrorMessage
	END CATCH

	BEGIN TRY
		EXEC gradCredits.GetExecutionLogDetailId 'AlterAddConstraints', @ExecutionLogId,
					@AlterAddConstraintsLogDetailId OUTPUT

		ALTER TABLE gradCredits.GradRequirementStudentSchoolAssociation
		ADD CONSTRAINT FK_GRADREQ_SCHID FOREIGN KEY (GradRequirementSchoolId) 
			REFERENCES gradCredits.GradRequirementSchool(GradRequirementSchoolId)

		ALTER table gradCredits.GradRequirementStudentGrade
		ADD CONSTRAINT FK_GRADREQ_SSAID FOREIGN KEY (GradRequirementStudentSchoolAssociationId) REFERENCES gradCredits.GradRequirementStudentSchoolAssociation(GradRequirementStudentSchoolAssociationId)


		ALTER table gradCredits.GradRequirementStudentCreditGrade
		ADD CONSTRAINT FK_GRADREQSC_SCGID FOREIGN KEY (GradRequirementStudentGradeId) REFERENCES gradCredits.GradRequirementStudentGrade(GradRequirementStudentGradeId)
	END TRY

	BEGIN CATCH
		SET @ErrorMessage =  CAST(ERROR_MESSAGE() as varchar(max))
		EXEC gradCredits.LogAudit @AlterAddConstraintsLogDetailId, @ErrorMessage
	END CATCH

	UPDATE gradCredits.GradRequirementExecutionLog
	SET ExecutionEnd = GETDATE(),
		ExecutionStatus = 'Success'
	WHERE GradRequirementExecutionLogId = @ExecutionLogId
	
END
GO



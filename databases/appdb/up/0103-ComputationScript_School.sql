
/****	ComputeSchoolGradCredits	***/
IF OBJECT_ID('gradCredits.ComputeSchoolGradCredits', 'P') IS NOT NULL
    DROP PROCEDURE gradCredits.ComputeSchoolGradCredits
GO



CREATE PROCEDURE gradCredits.ComputeSchoolGradCredits
	@SchoolId INT
AS

SET NOCOUNT ON

DECLARE
	@GradRequirementStudentId INT, 
	@GradRequirementSchoolId INT, 
	@GradRequirementSelectorId INT,
	@GradRequirementGradeLevelId INT,
	@SchoolYear SMALLINT,
	@GradRequirementStudentGradeId INT, 
	@EarnedCredits DECIMAL(6,3),
	@PassingGradeIndicator BIT,
	@SpecificGradRequirementId INT,
	@FirstSequenceGradRequirementId INT,
	@SecondSequenceGradRequirementId INT,
	@ThirdSequenceGradRequirementId INT,
	@FourthSequenceGradRequirementId INT,
	@GradRequirementGradingPeriodId INT,
	@LastGradedGradingPeriodId INT,
	@GradRequirementReferenceId INT,
	@TotalEarnedCredits DECIMAL(6,3),
	@CourseSequenceChanged BIT,
	@ProcName NVARCHAR(100) = 'ComputeGradCredits',
	@ExecStart DATETIME = GETDATE(),
	@ExecutionLogId INT,
	@GradRequirementCreditsLogDetailId INT,
	@GradRequirementCreditGradesLogDetailId INT


DECLARE @GradRequirementCreditsMerge table (MERGE_ACTION VARCHAR(20));
DECLARE @GradRequirementCreditGradesMerge table (MERGE_ACTION VARCHAR(20));

EXEC gradCredits.GetExecutionLogId @ProcName, @ExecStart, @ExecutionLogId OUTPUT

EXEC gradCredits.GetExecutionLogDetailId 'GradRequirementCredits', @ExecutionLogId, @GradRequirementCreditsLogDetailId OUTPUT
EXEC gradCredits.GetExecutionLogDetailId 'GradRequirementCreditGrades', @ExecutionLogId, @GradRequirementCreditGradesLogDetailId OUTPUT


DECLARE gc_cursor CURSOR FAST_FORWARD FOR 
	SELECT GradRequirementStudentId, GradRequirementSelectorId, CurrentGradeLevelId
	FROM gradCredits.GradRequirementStudent gr
	WHERE GradPathSchoolId = @SchoolId
 
OPEN gc_cursor
FETCH NEXT FROM gc_cursor
	INTO  @GradRequirementStudentId, @GradRequirementSelectorId, @GradRequirementGradeLevelId

	
WHILE @@FETCH_STATUS = 0
BEGIN

	IF OBJECT_ID('tempdb.dbo.#StudentComputedCredits', 'U') IS NOT NULL
		DROP TABLE #StudentComputedCredits;

	CREATE TABLE #StudentComputedCredits (
		GradRequirementStudentId INT,		
		GradRequirementGradeLevelId INT,		
		LastGradedQtr VARCHAR(10),	
		GradRequirementId INT,
		GradRequirement VARCHAR(200),
		EarnedGradCredits DECIMAL(6,3),
		RemainingCreditsRequiredByLastGradedQuarter DECIMAL(6,3),
		RemainingCreditsRequiredByEndOfCurrentGradeLevel DECIMAL(6,3),
		RemainingCreditsRequiredByGraduation DECIMAL(6,3),
		DifferentialRemainingCreditsRequiredByGraduation DECIMAL(6,3),
		TotalEarnedCredits DECIMAL(6,3),
		TotalEarnedGradCredits DECIMAL(6,3),
		CreditValueRequired DECIMAL(6,3),
		CreditValueRemaining DECIMAL(6,3),
		CreditDeficiencyStatus VARCHAR(25)
	)

	IF OBJECT_ID('tempdb.dbo.#StudentComputedCreditGrades', 'U') IS NOT NULL
		DROP TABLE #StudentComputedCreditGrades;

	CREATE TABLE #StudentComputedCreditGrades (
		GradRequirementStudentId INT,
		GradRequirementId INT,
		GradRequirementStudentGradeId INT,
		CreditsContributed DECIMAL(6,3)	
	)

	
	INSERT INTO #StudentComputedCredits(GradRequirementStudentId, 
		GradRequirementId, GradRequirement, GradRequirementGradeLevelId, EarnedGradCredits)
	SELECT DISTINCT  @GradRequirementStudentId, g.GradRequirementId, r.GradRequirement, @GradRequirementGradeLevelId, 0.00
	FROM gradCredits.GradRequirementReference g
	INNER JOIN gradCredits.GradRequirement r on g.GradRequirementId = r.GradRequirementId
	WHERE GradRequirementSelectorId = @GradRequirementSelectorId


		--get last graded quarter of student.
SET @LastGradedGradingPeriodId = (COALESCE(
		(SELECT DISTINCT grgp.GradRequirementGradingPeriodId 
		FROM gradCredits.GradRequirementStudentGrade grsg
		INNER JOIN gradCredits.GradRequirementStudentSchoolAssociation grssa
			ON grsg.GradRequirementStudentSchoolAssociationId = grssa.GradRequirementStudentSchoolAssociationId
		INNER JOIN gradCredits.GradRequirementGradingPeriod grgp
			ON grsg.GradRequirementGradingPeriodId = grgp.GradRequirementGradingPeriodId
		WHERE GradRequirementGradeLevelId = @GradRequirementGradeLevelId
		AND GradRequirementGradingPeriod = 'QTR 4'
		AND grsg.GradRequirementStudentId = @GradRequirementStudentId),
		(SELECT DISTINCT grgp.GradRequirementGradingPeriodId 
		FROM gradCredits.GradRequirementStudentGrade grsg
		INNER JOIN gradCredits.GradRequirementStudentSchoolAssociation grssa
			ON grsg.GradRequirementStudentSchoolAssociationId = grssa.GradRequirementStudentSchoolAssociationId
		INNER JOIN gradCredits.GradRequirementGradingPeriod grgp
			ON grsg.GradRequirementGradingPeriodId = grgp.GradRequirementGradingPeriodId
		WHERE GradRequirementGradeLevelId = @GradRequirementGradeLevelId
		AND GradRequirementGradingPeriod = 'QTR 3'
		AND grsg.GradRequirementStudentId = @GradRequirementStudentId),
		(SELECT DISTINCT grgp.GradRequirementGradingPeriodId 
		FROM gradCredits.GradRequirementStudentGrade grsg
		INNER JOIN gradCredits.GradRequirementStudentSchoolAssociation grssa
			ON grsg.GradRequirementStudentSchoolAssociationId = grssa.GradRequirementStudentSchoolAssociationId
		INNER JOIN gradCredits.GradRequirementGradingPeriod grgp
			ON grsg.GradRequirementGradingPeriodId = grgp.GradRequirementGradingPeriodId
		WHERE GradRequirementGradeLevelId = @GradRequirementGradeLevelId
		AND GradRequirementGradingPeriod = 'QTR 2'
		AND grsg.GradRequirementStudentId = @GradRequirementStudentId),
		(SELECT DISTINCT grgp.GradRequirementGradingPeriodId 
		FROM gradCredits.GradRequirementGradingPeriod grgp			
		WHERE GradRequirementGradingPeriod = 'QTR 1')))

	SET @TotalEarnedCredits = COALESCE((SELECT SUM(EarnedCredits) FROM gradCredits.GradRequirementStudentGrade
								WHERE GradRequirementStudentId = @GradRequirementStudentId), 0.000)

	DECLARE cc_cursor CURSOR FAST_FORWARD FOR 
		SELECT 
			GradRequirementStudentGradeId, 
			EarnedCredits,
			grssa.SchoolYear,
			GradRequirementGradingPeriodId,
			PassingGradeIndicator,
			SpecificGradRequirementId,
			FirstSequenceGradRequirementId,
			SecondSequenceGradRequirementId,
			ThirdSequenceGradRequirementId,
			FourthSequenceGradRequirementId
		FROM gradCredits.GradRequirementStudentGrade grsg
		INNER JOIN gradCredits.GradRequirementStudentSchoolAssociation grssa
			ON grsg.GradRequirementStudentSchoolAssociationId = grssa.GradRequirementStudentSchoolAssociationId
		INNER JOIN gradCredits.GradRequirementCourseSequence grcs 
			ON grsg.GradRequirementCourseSequenceId = grcs.GradRequirementCourseSequenceId
		WHERE grsg.GradRequirementStudentId = @GradRequirementStudentId
		ORDER BY grssa.SchoolYear ASC, CASE TERM WHEN 'Fall' THEN 0 WHEN 'Spring' THEN 1 WHEN 'Summer' THEN 2 END, DisplayCourseCode
	
	OPEN cc_cursor
	FETCH NEXT FROM cc_cursor
	INTO @GradRequirementStudentGradeId, @EarnedCredits, @SchoolYear, @GradRequirementGradingPeriodId, 
		@PassingGradeIndicator, @SpecificGradRequirementId, @FirstSequenceGradRequirementId, 
		@SecondSequenceGradRequirementId, @ThirdSequenceGradRequirementId, @FourthSequenceGradRequirementId
		
	WHILE @@FETCH_STATUS = 0
	BEGIN
		
		DECLARE @gradCounter INT = 1, @CurrentGradRequirementId INT, @requiredCreditValue DECIMAL(6,3), @earnedGradCreditValue DECIMAL(6,3) 
		DECLARE @cummulativeCredit DECIMAL(6,3) = 0.00
		DECLARE @ElectivesGradRequirementId INT = (SELECT GradRequirementId FROM gradCredits.GradRequirement 
														WHERE GradRequirement = 'Electives')			

		WHILE @gradCounter <= 6
			BEGIN
				IF(@gradCounter = 1) SET @CurrentGradRequirementId = @SpecificGradRequirementId
				ELSE IF(@gradCounter = 2) SET @CurrentGradRequirementId = @FirstSequenceGradRequirementId
				ELSE IF(@gradCounter = 3) SET @CurrentGradRequirementId = @SecondSequenceGradRequirementId
				ELSE IF(@gradCounter = 4) SET @CurrentGradRequirementId = @ThirdSequenceGradRequirementId
				ELSE IF(@gradCounter = 5) SET @CurrentGradRequirementId = @FourthSequenceGradRequirementId
				ELSE SET @CurrentGradRequirementId = @ElectivesGradRequirementId
			
				IF (@CurrentGradRequirementId IS NULL) 
				BEGIN
					SET @gradCounter += 1
					continue
				END


				DECLARE @PhysicsOrChemGradReqId INT = (SELECT GradRequirementId FROM #StudentComputedCredits WHERE GradRequirement = 'Chemistry or Physics')
				DECLARE @PhysicsGradReqId INT = (SELECT GradRequirementId FROM gradCredits.GradRequirement WHERE GradRequirement = 'Physics')
				DECLARE @ChemGradReqId INT = (SELECT GradRequirementId FROM gradCredits.GradRequirement WHERE GradRequirement = 'Chemistry')
				DECLARE @ChemOrPhysicsGradReqId INT = (SELECT GradRequirementId FROM gradCredits.GradRequirement WHERE GradRequirement = 'Chemistry or Physics')

				
				IF @PhysicsOrChemGradReqId IS NOT NULL 
					AND @CurrentGradRequirementId IN (@PhysicsGradReqId, @ChemGradReqId)
						SET @CurrentGradRequirementId = @PhysicsOrChemGradReqId

				IF @PhysicsOrChemGradReqId IS NULL
					AND @CurrentGradRequirementId = @ChemOrPhysicsGradReqId 
				BEGIN
					DECLARE @ChemistryReqCreditValue DECIMAL(6,3) 
						= (	SELECT CreditValue 
							FROM gradCredits.GradRequirementReference g		
							INNER JOIN gradCredits.GradRequirementGradeLevel gl 
								ON g.GradRequirementGradeLevelId = gl.GradRequirementGradeLevelId
							INNER JOIN gradCredits.GradRequirementGradingPeriod gp
								ON g.GradRequirementGradingPeriodId = gp.GradRequirementGradingPeriodId
							WHERE gp.GradRequirementGradingPeriod = 'QTR 4' 
								AND gl.GradRequirementGradeLevel = 12 
								AND GradRequirementId = @ChemGradReqId
								AND GradRequirementSelectorId = @GradRequirementSelectorId)

					DECLARE @ChemistryEarnedValue DECIMAL(6,3) 
						= (SELECT EarnedGradCredits FROM #StudentComputedCredits
							WHERE GradRequirementId = @ChemGradReqId)	
					
							
					IF @ChemistryEarnedValue < @ChemistryReqCreditValue
						SET @CurrentGradRequirementId = @ChemGradReqId
					ELSE
						SET @CurrentGradRequirementId = @PhysicsGradReqId 

				END
				
				SET @requiredCreditValue = (SELECT CreditValue 
											FROM gradCredits.GradRequirementReference g		
											INNER JOIN gradCredits.GradRequirementGradeLevel gl 
												ON g.GradRequirementGradeLevelId = gl.GradRequirementGradeLevelId
											INNER JOIN gradCredits.GradRequirementGradingPeriod gp
												ON g.GradRequirementGradingPeriodId = gp.GradRequirementGradingPeriodId
											WHERE gp.GradRequirementGradingPeriod = 'QTR 4' 
												AND gl.GradRequirementGradeLevel = 12 
												AND GradRequirementId = @CurrentGradRequirementId
												AND GradRequirementSelectorId = @GradRequirementSelectorId)
						
				SET @earnedGradCreditValue = (SELECT EarnedGradCredits FROM #StudentComputedCredits
												WHERE GradRequirementId = @CurrentGradRequirementId)	
														
				IF(@cummulativeCredit > 0) SET @EarnedCredits = @cummulativeCredit;		
		
				IF(@CurrentGradRequirementId = @ElectivesGradRequirementId)
					BEGIN
						DECLARE @newElectiveValue DECIMAL(6,3)
						SET @newElectiveValue = @earnedGradCreditValue + @EarnedCredits

						INSERT INTO #StudentComputedCreditGrades
						SELECT @GradRequirementStudentId, @CurrentGradRequirementId, @GradRequirementStudentGradeId, @EarnedCredits						
						
						IF @newElectiveValue >= @requiredCreditValue
							UPDATE #StudentComputedCredits SET EarnedGradCredits = @requiredCreditValue
							WHERE GradRequirementId = @CurrentGradRequirementId 
						ELSE	
							UPDATE #StudentComputedCredits SET EarnedGradCredits = @newElectiveValue
							WHERE GradRequirementId = @CurrentGradRequirementId

						break
					END
				ELSE
					BEGIN						
						IF(@earnedGradCreditValue < @requiredCreditValue)
						BEGIN
							DECLARE @newValue DECIMAL(6,3)

							SET @newValue = @EarnedCredits + @earnedGradCreditValue

							IF(@newValue >= @requiredCreditValue)
								BEGIN
									UPDATE #StudentComputedCredits SET EarnedGradCredits = @requiredCreditValue
									WHERE GradRequirementId = @CurrentGradRequirementId
										
									INSERT INTO #StudentComputedCreditGrades
									SELECT @GradRequirementStudentId, @CurrentGradRequirementId, @GradRequirementStudentGradeId,
										(@requiredCreditValue - @earnedGradCreditValue)	
									
									IF @newValue = @requiredCreditValue 
										break

									SET @cummulativeCredit = @newValue - @requiredCreditValue 

									
								END
							ELSE
								BEGIN
									UPDATE #StudentComputedCredits SET EarnedGradCredits = @newValue
									WHERE GradRequirementId = @CurrentGradRequirementId

									IF (@earnedGradCreditValue <> @requiredCreditValue)
										INSERT INTO #StudentComputedCreditGrades
										SELECT @GradRequirementStudentId, @CurrentGradRequirementId, @GradRequirementStudentGradeId, @EarnedCredits

									break
								END
						END						
					END
				SET @gradCounter += 1

			END

		FETCH NEXT FROM cc_cursor
		INTO @GradRequirementStudentGradeId, @EarnedCredits, @SchoolYear, @GradRequirementGradingPeriodId, 
			@PassingGradeIndicator, @SpecificGradRequirementId, @FirstSequenceGradRequirementId, 
			@SecondSequenceGradRequirementId, @ThirdSequenceGradRequirementId, @FourthSequenceGradRequirementId
	END

	CLOSE cc_cursor
	DEALLOCATE cc_cursor

	-- Updates --
	DECLARE @TotalEarnedGradCredits DECIMAL(10,2) = (SELECT SUM(EarnedGradCredits) FROM #StudentComputedCredits)

	UPDATE ct
	SET RemainingCreditsRequiredByLastGradedQuarter = IIF((g.CreditValue - ct.EarnedGradCredits) < 0, 0, (g.CreditValue - ct.EarnedGradCredits)),
		LastGradedQtr = @LastGradedGradingPeriodId
	FROM #StudentComputedCredits ct
	JOIN (
		SELECT GradRequirementId, CreditValue 
		FROM gradCredits.GradRequirementReference		
		WHERE GradRequirementGradeLevelId = @GradRequirementGradeLevelId
			AND GradRequirementGradingPeriodId = @LastGradedGradingPeriodId
			AND GradRequirementSelectorId = @GradRequirementSelectorId
	) g ON g.GradRequirementId = ct.GradRequirementId

	UPDATE ct
	SET RemainingCreditsRequiredByEndOfCurrentGradeLevel = IIF((g.CreditValue - ct.EarnedGradCredits) < 0, 0, (g.CreditValue - ct.EarnedGradCredits))
	FROM #StudentComputedCredits ct
	JOIN (
		SELECT GradRequirementId, CreditValue 
		FROM gradCredits.GradRequirementReference gr
		INNER JOIN gradCredits.GradRequirementGradingPeriod grp
			ON gr.GradRequirementGradingPeriodId = grp.GradRequirementGradingPeriodId
		WHERE GradRequirementGradeLevelId = @GradRequirementGradeLevelId 
			AND GradRequirementSelectorId = @GradRequirementSelectorId
			AND GradRequirementGradingPeriod = 'QTR 4'
	) g ON g.GradRequirementId = ct.GradRequirementId



	UPDATE ct
	SET DifferentialRemainingCreditsRequiredByGraduation = IIF((g.CreditValue - (ct.EarnedGradCredits + RemainingCreditsRequiredByLastGradedQuarter))
			 < 0, 0, (g.CreditValue - (ct.EarnedGradCredits + RemainingCreditsRequiredByLastGradedQuarter))),
		CreditValueRequired = g.CreditValue, CreditValueRemaining = (g.CreditValue - EarnedGradCredits),
		RemainingCreditsRequiredByGraduation = IIF((g.CreditValue - ct.EarnedGradCredits) < 0, 0, (g.CreditValue - ct.EarnedGradCredits))
	FROM #StudentComputedCredits ct
	JOIN (
		SELECT GradRequirementId, CreditValue 
		FROM gradCredits.GradRequirementReference gr
		INNER JOIN gradCredits.GradRequirementGradingPeriod grp
			ON gr.GradRequirementGradingPeriodId = grp.GradRequirementGradingPeriodId
		INNER JOIN gradCredits.GradRequirementGradeLevel gl
			ON gr.GradRequirementGradeLevelId = gl.GradRequirementGradeLevelId
		WHERE GradRequirementGradeLevel = 12 
			AND GradRequirementSelectorId = @GradRequirementSelectorId
			AND GradRequirementGradingPeriod = 'QTR 4'
	) g ON g.GradRequirementId = ct.GradRequirementId


	UPDATE #StudentComputedCredits
	SET TotalEarnedGradCredits = @TotalEarnedGradCredits, TotalEarnedCredits = @TotalEarnedCredits,
		CreditDeficiencyStatus = CASE WHEN RemainingCreditsRequiredByLastGradedQuarter > 0 
								THEN  'Not Meeting Requirements' ELSE  'Meeting Requirements' END	
	
	BEGIN TRY
		BEGIN TRANSACTION

			;WITH GradRequirementStudentCredit AS
			(
				SELECT * FROM gradCredits.GradRequirementStudentCredit
				WHERE GradRequirementStudentId = @GradRequirementStudentId
			)
			MERGE INTO GradRequirementStudentCredit AS TARGET
			USING #StudentComputedCredits AS SOURCE
			ON TARGET.GradRequirementStudentId = SOURCE.GradRequirementStudentId
				AND TARGET.GradRequirementId = SOURCE.GradRequirementId		
			WHEN MATCHED AND 
				(LastGradedGradingPeriodId <> LastGradedQtr OR  
				EarnedCredits <> EarnedGradCredits OR  
				TARGET.RemainingCreditsRequiredByLastGradedQuarter <> SOURCE.RemainingCreditsRequiredByLastGradedQuarter OR  
				TARGET.RemainingCreditsRequiredByEndOfCurrentGradeLevel <> SOURCE.RemainingCreditsRequiredByEndOfCurrentGradeLevel OR  
				TARGET.RemainingCreditsRequiredByGraduation <> SOURCE.RemainingCreditsRequiredByGraduation OR  
				TARGET.DifferentialRemainingCreditsRequiredByGraduation <> SOURCE.DifferentialRemainingCreditsRequiredByGraduation OR  
				TARGET.TotalEarnedCredits <> SOURCE.TotalEarnedCredits OR  
				TARGET.TotalEarnedGradCredits <> SOURCE.TotalEarnedGradCredits OR  
				TARGET.CreditValueRequired <> SOURCE.CreditValueRequired OR  
				TARGET.CreditValueRemaining <> SOURCE.CreditValueRemaining OR  
				TARGET.CreditDeficiencyStatus <> SOURCE.CreditDeficiencyStatus)
			THEN UPDATE SET LastGradedGradingPeriodId = LastGradedQtr, 
						EarnedCredits = EarnedGradCredits,
						RemainingCreditsRequiredByLastGradedQuarter = SOURCE.RemainingCreditsRequiredByLastGradedQuarter,
						RemainingCreditsRequiredByEndOfCurrentGradeLevel = SOURCE.RemainingCreditsRequiredByEndOfCurrentGradeLevel,
						RemainingCreditsRequiredByGraduation = SOURCE.RemainingCreditsRequiredByGraduation,
						DifferentialRemainingCreditsRequiredByGraduation = SOURCE.DifferentialRemainingCreditsRequiredByGraduation,
						TotalEarnedCredits = SOURCE.TotalEarnedCredits,
						TotalEarnedGradCredits = SOURCE.TotalEarnedGradCredits,
						CreditValueRequired = SOURCE.CreditValueRequired,
						CreditValueRemaining = 	SOURCE.CreditValueRemaining,
						CreditDeficiencyStatus = SOURCE.CreditDeficiencyStatus
			WHEN NOT MATCHED THEN
				INSERT (GradRequirementStudentId, GradRequirementId,
						LastGradedGradingPeriodId, EarnedCredits, RemainingCreditsRequiredByLastGradedQuarter,
						RemainingCreditsRequiredByEndOfCurrentGradeLevel, RemainingCreditsRequiredByGraduation,
						DifferentialRemainingCreditsRequiredByGraduation, TotalEarnedCredits, TotalEarnedGradCredits,
						CreditValueRequired, CreditValueRemaining, CreditDeficiencyStatus)
				VALUES (SOURCE.GradRequirementStudentId, SOURCE.GradRequirementId, 
						LastGradedQtr, EarnedGradCredits, SOURCE.RemainingCreditsRequiredByLastGradedQuarter,
						SOURCE.RemainingCreditsRequiredByEndOfCurrentGradeLevel, SOURCE.RemainingCreditsRequiredByGraduation,
						SOURCE.DifferentialRemainingCreditsRequiredByGraduation, SOURCE.TotalEarnedCredits, SOURCE.TotalEarnedGradCredits,
						SOURCE.CreditValueRequired, SOURCE.CreditValueRemaining, SOURCE.CreditDeficiencyStatus)
			WHEN NOT MATCHED BY SOURCE THEN
				DELETE
			OUTPUT $action INTO @GradRequirementCreditsMerge
			;	


			;WITH GradRequirementStudentCreditGrade AS
			(
				SELECT scg.* FROM gradCredits.GradRequirementStudentCreditGrade scg
				INNER JOIN gradCredits.GradRequirementStudentCredit gcs
					ON scg.GradRequirementStudentId = gcs.GradRequirementStudentId
					AND scg.GradRequirementStudentCreditId = gcs.GradRequirementStudentCreditId
				WHERE scg.GradRequirementStudentId = @GradRequirementStudentId
			)
			MERGE INTO GradRequirementStudentCreditGrade AS TARGET
			USING (SELECT scg.GradRequirementStudentId, gcs.GradRequirementStudentCreditId, 
						scg.GradRequirementStudentGradeId, SUM(scg.CreditsContributed) CreditsContributed
					FROM #StudentComputedCreditGrades scg
					INNER JOIN gradCredits.GradRequirementStudentCredit gcs
						ON scg.GradRequirementStudentId = gcs.GradRequirementStudentId
						AND scg.GradRequirementId = gcs.GradRequirementId
					GROUP BY scg.GradRequirementStudentId, gcs.GradRequirementStudentCreditId, 
						scg.GradRequirementStudentGradeId) AS SOURCE
			ON TARGET.GradRequirementStudentId = SOURCE.GradRequirementStudentId
			AND TARGET.GradRequirementStudentCreditId = SOURCE.GradRequirementStudentCreditId
			AND TARGET.GradRequirementStudentGradeId = SOURCE.GradRequirementStudentGradeId			
			WHEN MATCHED 
			AND TARGET.CreditsContributed <> SOURCE.CreditsContributed
			THEN UPDATE SET TARGET.CreditsContributed = SOURCE.CreditsContributed
			WHEN NOT MATCHED THEN
				INSERT (GradRequirementStudentId, GradRequirementStudentCreditId, GradRequirementStudentGradeId, CreditsContributed)
				VALUES (SOURCE.GradRequirementStudentId, SOURCE.GradRequirementStudentCreditId, SOURCE.GradRequirementStudentGradeId, SOURCE.CreditsContributed)
			WHEN NOT MATCHED BY SOURCE THEN
				DELETE
			OUTPUT $action INTO @GradRequirementCreditGradesMerge
			;			


		COMMIT TRANSACTION
	END TRY

	BEGIN CATCH
		IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
		THROW;
	END CATCH


	FETCH NEXT FROM gc_cursor
		INTO  @GradRequirementStudentId, @GradRequirementSelectorId, @GradRequirementGradeLevelId
END

CLOSE gc_cursor
DEALLOCATE gc_cursor

		UPDATE gradCredits.GradRequirementExecutionLogDetail
		SET RecordsInserted = COALESCE(RecordsInserted, 0) + (SELECT SUM(CASE WHEN MERGE_ACTION='INSERT' THEN 1 ELSE 0 END)
								from @GradRequirementCreditsMerge), 
			RecordsUpdated = COALESCE(RecordsUpdated, 0) + (SELECT SUM(CASE WHEN MERGE_ACTION='UPDATE' THEN 1 ELSE 0 END)
								from @GradRequirementCreditsMerge),
			RecordsDeleted = COALESCE(RecordsDeleted, 0) + (SELECT SUM(CASE WHEN MERGE_ACTION='DELETE' THEN 1 ELSE 0 END)
								from @GradRequirementCreditsMerge)
		WHERE GradRequirementExecutionLogDetailId = @GradRequirementCreditsLogDetailId;


		UPDATE gradCredits.GradRequirementExecutionLogDetail
		SET RecordsInserted = COALESCE(RecordsInserted,0) + (SELECT SUM(CASE WHEN MERGE_ACTION='INSERT' THEN 1 ELSE 0 END)
								from @GradRequirementCreditGradesMerge), 
			RecordsUpdated = COALESCE(RecordsUpdated,0) + (SELECT SUM(CASE WHEN MERGE_ACTION='UPDATE' THEN 1 ELSE 0 END)
								from @GradRequirementCreditGradesMerge),
			RecordsDeleted = COALESCE(RecordsDeleted,0) + (SELECT SUM(CASE WHEN MERGE_ACTION='DELETE' THEN 1 ELSE 0 END)
								from @GradRequirementCreditGradesMerge)


GO



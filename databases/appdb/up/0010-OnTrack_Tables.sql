IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = N'gradCredits')
	EXEC sys.sp_executesql N'CREATE SCHEMA [gradCredits]'
GO

IF OBJECT_ID('gradCredits.GradRequirementStudentCreditGrade',N'U') IS NOT NULL
	DROP TABLE gradCredits.GradRequirementStudentCreditGrade
GO

IF OBJECT_ID('gradCredits.GradRequirementStudentGrade',N'U') IS NOT NULL
	DROP TABLE gradCredits.GradRequirementStudentGrade
GO

IF OBJECT_ID('gradCredits.GradRequirementStudentCredit',N'U') IS NOT NULL
	DROP TABLE gradCredits.GradRequirementStudentCredit
GO


IF OBJECT_ID('gradCredits.GradRequirementCourseSequence',N'U') IS NOT NULL
	DROP TABLE gradCredits.GradRequirementCourseSequence
GO


IF OBJECT_ID('gradCredits.GradRequirementStudentSchoolAssociation',N'U') IS NOT NULL
	DROP TABLE gradCredits.GradRequirementStudentSchoolAssociation
GO

IF OBJECT_ID('gradCredits.GradRequirementStudent',N'U') IS NOT NULL
	DROP TABLE gradCredits.GradRequirementStudent
GO


IF OBJECT_ID('gradCredits.GradRequirementSchoolYear',N'U') IS NOT NULL
	DROP TABLE gradCredits.GradRequirementSchoolYear
GO


IF OBJECT_ID('gradCredits.GradRequirementReference',N'U') IS NOT NULL
	DROP TABLE gradCredits.GradRequirementReference
GO

IF OBJECT_ID('gradCredits.GradRequirementSelector',N'U') IS NOT NULL
	DROP TABLE gradCredits.GradRequirementSelector
GO


IF OBJECT_ID('gradCredits.GradRequirementSchool',N'U') IS NOT NULL
	DROP TABLE gradCredits.GradRequirementSchool
GO


IF OBJECT_ID('gradCredits.GradRequirementStudentGroup',N'U') IS NOT NULL
	DROP TABLE gradCredits.GradRequirementStudentGroup
GO


IF OBJECT_ID('gradCredits.GradRequirementGradingPeriod',N'U') IS NOT NULL
	DROP TABLE gradCredits.GradRequirementGradingPeriod
GO


IF OBJECT_ID('gradCredits.GradRequirementGradeLevel',N'U') IS NOT NULL
	DROP TABLE gradCredits.GradRequirementGradeLevel
GO



IF OBJECT_ID('gradCredits.GradRequirement',N'U') IS NOT NULL
	DROP TABLE gradCredits.GradRequirement
GO

IF OBJECT_ID('gradCredits.GradRequirementDepartment',N'U') IS NOT NULL
	DROP TABLE gradCredits.GradRequirementDepartment
GO


CREATE TABLE gradCredits.GradRequirementDepartment
(
	GradRequirementDepartmentId INT IDENTITY(1,1),
	GradRequirementDepartment NVARCHAR(100) NOT NULL,
	CONSTRAINT PK_GRAD_REQ_DPT PRIMARY KEY (GradRequirementDepartmentId),
	CONSTRAINT UX_GRAD_REQ_DPT UNIQUE (GradRequirementDepartment),
)


CREATE TABLE gradCredits.GradRequirement
(
	GradRequirementId INT IDENTITY(1000,1),
	GradRequirement NVARCHAR(200) NOT NULL,	
	CONSTRAINT PK_GRAD_REQ PRIMARY KEY (GradRequirementId),
	CONSTRAINT UX_GRAD_REQ UNIQUE (GradRequirement)	
)
GO




CREATE TABLE gradCredits.GradRequirementGradeLevel
(
	GradRequirementGradeLevelId INT IDENTITY(1,1),
	GradRequirementGradeLevel INT NOT NULL,
	GradRequirementGradeLevelDescription VARCHAR(25) NULL,
	CONSTRAINT PK_GRAD_REQ_GL PRIMARY KEY (GradRequirementGradeLevelId),
	CONSTRAINT UX_GRAD_REQ_GL UNIQUE (GradRequirementGradeLevel)
)
GO


CREATE TABLE gradCredits.GradRequirementGradingPeriod
(
	GradRequirementGradingPeriodId INT IDENTITY(1,1),
	GradRequirementGradingPeriod NVARCHAR(50) NOT NULL,
	CONSTRAINT PK_GRAD_REQ_GP PRIMARY KEY (GradRequirementGradingPeriodId),
	CONSTRAINT UX_GRAD_REQ_GP UNIQUE (GradRequirementGradingPeriod)
)



CREATE TABLE gradCredits.GradRequirementStudentGroup
(
	GradRequirementStudentGroupId INT IDENTITY(1,1),
	GradRequirementStudentGroup NVARCHAR(100) NOT NULL,
	CONSTRAINT PK_GRAD_REQ_STDGRP PRIMARY KEY (GradRequirementStudentGroupId),
	CONSTRAINT UX_GRAD_REQ_STDGRP UNIQUE (GradRequirementStudentGroup)
)


CREATE TABLE gradCredits.GradRequirementSchool
(
	GradRequirementSchoolId INT NOT NULL,
	GradRequirementSchoolName NVARCHAR(100) NOT NULL,
	CONSTRAINT PK_GRAD_REQ_SCH PRIMARY KEY (GradRequirementSchoolId),
	CONSTRAINT UX_GRAD_REQ_SCH UNIQUE (GradRequirementSchoolName)
)


CREATE TABLE gradCredits.GradRequirementSelector
(
	GradRequirementSelectorId INT IDENTITY(1,1),
	GradRequirementSelector NVARCHAR(50) NOT NULL,
	GradRequirementSchoolId INT NOT NULL,
	GradRequirementStudentGroupId INT NULL,
	CONSTRAINT PK_GRAD_SEL_GP PRIMARY KEY (GradRequirementSelectorId),
	CONSTRAINT UX_GRAD_SEL_GP UNIQUE (GradRequirementSelector,GradRequirementSchoolId,GradRequirementStudentGroupId),
	CONSTRAINT FK_GRAD_SEL_SCH FOREIGN KEY (GradRequirementSchoolId) 
		REFERENCES gradCredits.GradRequirementSchool(GradRequirementSchoolId),
	CONSTRAINT FK_GRAD_SEL_STDGP FOREIGN KEY (GradRequirementStudentGroupId) 
		REFERENCES gradCredits.GradRequirementStudentGroup(GradRequirementStudentGroupId)

)



CREATE TABLE gradCredits.GradRequirementReference
(
	GradRequirementReferenceId INT IDENTITY(1,1),
	GradRequirementSelectorId INT NOT NULL,
	GradRequirementId INT NOT NULL,
	GradRequirementGradeLevelId INT NOT NULL,
	GradRequirementGradingPeriodId INT NOT NULL,
	GradRequirementDepartmentId INT NOT NULL,
	CreditValue DECIMAL(6,3) NOT NULL,
	CONSTRAINT PK_GRAD_REQ_REFID PRIMARY KEY (GradRequirementReferenceId),
	CONSTRAINT UX_GRAD_REQ_REF UNIQUE (GradRequirementSelectorId,GradRequirementId,	
		GradRequirementGradeLevelId,GradRequirementGradingPeriodId,GradRequirementDepartmentId),
	CONSTRAINT FK_GRAD_SEL FOREIGN KEY (GradRequirementSelectorId) 
		REFERENCES gradCredits.GradRequirementSelector(GradRequirementSelectorId),
	CONSTRAINT FK_GRAD_RQ FOREIGN KEY (GradRequirementId) 
		REFERENCES gradCredits.GradRequirement(GradRequirementId),
	CONSTRAINT FK_GRAD_GL FOREIGN KEY (GradRequirementGradeLevelId) 
		REFERENCES gradCredits.GradRequirementGradeLevel(GradRequirementGradeLevelId),
	CONSTRAINT FK_GRAD_GP FOREIGN KEY (GradRequirementGradingPeriodId) 
		REFERENCES gradCredits.GradRequirementGradingPeriod(GradRequirementGradingPeriodId),
	CONSTRAINT FK_GRAD_DPT FOREIGN KEY (GradRequirementDepartmentId)
		REFERENCES gradCredits.GradRequirementDepartment(GradRequirementDepartmentId)
)



CREATE TABLE gradCredits.GradRequirementCourseSequence
(
	GradRequirementCourseSequenceId INT IDENTITY(1,1),
	CourseCode NVARCHAR(50) NOT NULL,
	CourseTitle NVARCHAR(255) NOT NULL,
	SchoolYear SMALLINT NOT NULL,
	Duration NVARCHAR(50) NULL,
	GradRequirementDepartmentId INT NULL,
	CreditValue DECIMAL(6,3) NOT NULL,
	SpecificGradRequirementId INT NOT NULL,
	FirstSequenceGradRequirementId INT NULL,
	SecondSequenceGradRequirementId INT NULL,
	ThirdSequenceGradRequirementId INT NULL,
	FourthSequenceGradRequirementId INT NULL,
	CONSTRAINT PK_GRAD_REQ_CM PRIMARY KEY (GradRequirementCourseSequenceId),
	CONSTRAINT UX_GRAD_REQ_CM UNIQUE (CourseCode, SchoolYear),
	CONSTRAINT FK_GRAD_DEPT FOREIGN KEY (GradRequirementDepartmentId) 
		REFERENCES gradCredits.GradRequirementDepartment(GradRequirementDepartmentId),
	CONSTRAINT FK_GRAD_RQ_CM FOREIGN KEY (SpecificGradRequirementId) 
		REFERENCES gradCredits.GradRequirement(GradRequirementId),
	CONSTRAINT FK_GRAD_RQ1_CM FOREIGN KEY (FirstSequenceGradRequirementId) 
		REFERENCES gradCredits.GradRequirement(GradRequirementId),
	CONSTRAINT FK_GRAD_RQ2_CM FOREIGN KEY (SecondSequenceGradRequirementId) 
		REFERENCES gradCredits.GradRequirement(GradRequirementId),
	CONSTRAINT FK_GRAD_RQ3_CM FOREIGN KEY (ThirdSequenceGradRequirementId) 
		REFERENCES gradCredits.GradRequirement(GradRequirementId),
	CONSTRAINT FK_GRAD_RQ4_CM FOREIGN KEY (FourthSequenceGradRequirementId) 
		REFERENCES gradCredits.GradRequirement(GradRequirementId)
)
GO


CREATE TABLE gradCredits.GradRequirementStudent
(
	GradRequirementStudentId INT IDENTITY(1,1),
	StudentUSI INT NOT NULL,
	StudentUniqueId INT NOT NULL,
	StudentChartId INT NOT NULL,
	StudentDistrictId INT NOT NULL,
	StudentName NVARCHAR(255) NOT NULL,
	GradPathSchoolId INT NULL,
	CurrentGradeLevelId INT NULL,
	GradRequirementSelectorId INT NULL,
	CONSTRAINT PK_GRAD_REQ_STD PRIMARY KEY (GradRequirementStudentId),
	CONSTRAINT UX_GRAD_REQ_STD UNIQUE (StudentUniqueId),
	CONSTRAINT FK_GRADREQ_SELID FOREIGN KEY (GradRequirementSelectorId) 
		REFERENCES gradCredits.GradRequirementSelector(GradRequirementSelectorId),
	CONSTRAINT FK_GRAD_REQ_GPS FOREIGN KEY (GradPathSchoolId) 
		REFERENCES gradCredits.GradRequirementSchool(GradRequirementSchoolId),
	CONSTRAINT FK_GRAD_REQ_GLS FOREIGN KEY (CurrentGradeLevelId) 
		REFERENCES gradCredits.GradRequirementGradeLevel(GradRequirementGradeLevelId)
)
GO


CREATE TABLE gradCredits.GradRequirementSchoolYear
(
	SchoolYear SMALLINT NOT NULL,
	CurrentSchoolYearIndicator BIT NOT NULL,
	CONSTRAINT PK_GRAD_REQ_SCHYR PRIMARY KEY (SchoolYear)
)
GO


CREATE TABLE gradCredits.GradRequirementStudentSchoolAssociation
(
	GradRequirementStudentSchoolAssociationId INT IDENTITY(1,1),
	GradRequirementStudentId INT NOT NULL,
	GradRequirementSchoolId INT NOT NULL,
	SchoolYear SMALLINT NOT NULL,
	GradRequirementGradeLevelId INT NOT NULL,
	CONSTRAINT PK_GRADREQ_SSA PRIMARY KEY (GradRequirementStudentSchoolAssociationId),
	CONSTRAINT UX_GRADREQ_SSA UNIQUE (GradRequirementStudentId,GradRequirementSchoolId,SchoolYear,GradRequirementGradeLevelId),
	CONSTRAINT FK_GRADREQ_STDID FOREIGN KEY (GradRequirementStudentId) REFERENCES gradCredits.GradRequirementStudent(GradRequirementStudentId),
	CONSTRAINT FK_GRADREQ_SCHYR FOREIGN KEY (SchoolYear) REFERENCES gradCredits.GradRequirementSchoolYear(SchoolYear),
	CONSTRAINT FK_GRADREQ_SCHID FOREIGN KEY (GradRequirementSchoolId) REFERENCES gradCredits.GradRequirementSchool(GradRequirementSchoolId),
	CONSTRAINT FK_GRADREQ_GLID FOREIGN KEY (GradRequirementGradeLevelId) REFERENCES gradCredits.GradRequirementGradeLevel(GradRequirementGradeLevelId)
)
GO


CREATE TABLE gradCredits.GradRequirementStudentGrade
(
	GradRequirementStudentGradeId INT IDENTITY(1,1),
	GradRequirementStudentId INT NOT NULL,
	GradRequirementStudentSchoolAssociationId INT NOT NULL,
	CourseCode NVARCHAR(60) NOT NULL,	
	DisplayCourseCode NVARCHAR(60) NOT NULL,
	CourseTitle NVARCHAR(60) NOT NULL,
	Term NVARCHAR(60) NOT NULL,
	GradRequirementGradingPeriodId INT NULL,
	LetterGradeEarned NVARCHAR(10) NULL,
	EarnedCredits DECIMAL(6,3) NOT NULL, 
	PassingGradeIndicator BIT NOT NULL,
	GradRequirementCourseSequenceId INT NULL,
	GradeSource VARCHAR(25) NOT NULL,
	CONSTRAINT PK_GRADREQ_STDGRD PRIMARY KEY (GradRequirementStudentGradeId),
	CONSTRAINT UX_GRADREQ_STDGRD UNIQUE (GradRequirementStudentId,GradRequirementStudentSchoolAssociationId,CourseCode,Term,GradRequirementGradingPeriodId,EarnedCredits,PassingGradeIndicator, LetterGradeEarned),
	CONSTRAINT FK_GRADREQ_SSAID FOREIGN KEY (GradRequirementStudentSchoolAssociationId) REFERENCES gradCredits.GradRequirementStudentSchoolAssociation(GradRequirementStudentSchoolAssociationId),
	CONSTRAINT FK_GRADREQ_SGPID FOREIGN KEY (GradRequirementGradingPeriodId) REFERENCES gradCredits.GradRequirementGradingPeriod(GradRequirementGradingPeriodId),
	CONSTRAINT FK_GRADREQ_SCSQ FOREIGN KEY (GradRequirementCourseSequenceId) REFERENCES gradCredits.GradRequirementCourseSequence(GradRequirementCourseSequenceId),
	CONSTRAINT FK_GRADREQ_STGID FOREIGN KEY (GradRequirementStudentId) REFERENCES gradCredits.GradRequirementStudent(GradRequirementStudentId)
)
GO



CREATE TABLE gradCredits.GradRequirementStudentCredit
(
	GradRequirementStudentCreditId INT IDENTITY(1,1),
	GradRequirementStudentId INT NOT NULL,
	GradRequirementId INT NOT NULL,
	LastGradedGradingPeriodId INT NOT NULL,	
	EarnedCredits DECIMAL(6,3) NOT NULL,
	RemainingCreditsRequiredByLastGradedQuarter DECIMAL(6,3) NOT NULL,
	RemainingCreditsRequiredByEndOfCurrentGradeLevel DECIMAL(6,3) NOT NULL,
	RemainingCreditsRequiredByGraduation DECIMAL(6,3) NOT NULL,
	DifferentialRemainingCreditsRequiredByGraduation DECIMAL(6,3) NOT NULL,
	TotalEarnedCredits DECIMAL(6,3) NOT NULL,
	TotalEarnedGradCredits DECIMAL(6,3) NOT NULL,
	CreditValueRequired DECIMAL(6,3) NOT NULL,
	CreditValueRemaining DECIMAL(6,3) NOT NULL,	
	CreditDeficiencyStatus VARCHAR(25) NOT NULL,
	CONSTRAINT PK_GRADREQSC_STDCR PRIMARY KEY (GradRequirementStudentCreditId),
	CONSTRAINT UX_GRADREQSC_STDCR UNIQUE (GradRequirementStudentId,GradRequirementId),
	CONSTRAINT FK_GRADREQSC_SRF FOREIGN KEY (GradRequirementId) REFERENCES gradCredits.GradRequirement(GradRequirementId),
	CONSTRAINT FK_GRADREQSC_STDID FOREIGN KEY (GradRequirementStudentId) REFERENCES gradCredits.GradRequirementStudent(GradRequirementStudentId),
	CONSTRAINT FK_GRADREQSC_SGPD FOREIGN KEY (LastGradedGradingPeriodId) REFERENCES gradCredits.GradRequirementGradingPeriod(GradRequirementGradingPeriodId)
)
GO




CREATE TABLE gradCredits.GradRequirementStudentCreditGrade
(
	GradRequirementStudentCreditGradeId INT IDENTITY(1,1),
	GradRequirementStudentId INT NOT NULL,
	GradRequirementStudentCreditId INT NOT NULL,
	GradRequirementStudentGradeId INT NOT NULL,
	CreditsContributed DECIMAL(6,3) NOT NULL,	
	CONSTRAINT PK_GRADREQSC_STDCRG PRIMARY KEY (GradRequirementStudentCreditGradeId),
	CONSTRAINT UX_GRADREQSC_STDCRG UNIQUE (GradRequirementStudentId,GradRequirementStudentCreditId,GradRequirementStudentGradeId),
	CONSTRAINT FK_GRADREQSC_SCGCD FOREIGN KEY (GradRequirementStudentCreditId) REFERENCES gradCredits.GradRequirementStudentCredit(GradRequirementStudentCreditId)
	ON UPDATE CASCADE ON DELETE CASCADE,
	CONSTRAINT FK_GRADREQSC_SCGID FOREIGN KEY (GradRequirementStudentGradeId) REFERENCES gradCredits.GradRequirementStudentGrade(GradRequirementStudentGradeId),
	CONSTRAINT FK_GRADREQSC_SCID FOREIGN KEY (GradRequirementStudentId) REFERENCES gradCredits.GradRequirementStudent(GradRequirementStudentId),
)
GO


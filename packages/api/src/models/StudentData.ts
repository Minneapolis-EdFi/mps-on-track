export interface StudentData {
	StudentNameSortOrder: number;
	StudentUSI: number;
	StudentID: string;
	StudentName: string | null;
	SchoolName: string | null;
	LastGradedQuarter: string | null;
	CurrentGradeLevel: string | null;
	CreditDeficiencyStatus: string | null;
	TotalEarnedCredits: number | null;
	TotalEarnedGradCredits: number | null;
	SurnameGroup: string;
}

export interface StudentDataResponse {
	StudentName: string;
	LastGradedQuarter: string;
	CurrentGradeLevel: string;
	CreditDeficiencyStatus: string;
	TotalEarnedCredits: number;
	TotalEarnedGradCredits: number;
}

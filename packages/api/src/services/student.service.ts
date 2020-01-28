import * as sql from 'mssql';
import { groupBy, isEmpty } from 'lodash';

import {
	StudentGradeBreakdownResponse,
	StudentDataResponse,
	StudentAtAGlanceResponse
} from '../models';
import { StudentCourseCreditResponse } from '../models/StudentCourseCredit';

interface StudentGradeBreakdownQuery {
	GradRequirement: string;
	EarnedGradCredits: number;
	RemainingCreditsRequiredByLastGradedQuarter: number;
	RemainingCreditsRequiredByEndOfCurrentGradeLevel: number;
	DifferentialRemainingCreditsRequiredByGraduation: number;
	RemainingCreditsRequiredByGraduation: number;
	TotalGradCredits: number;
	TotalRequiredByLastGradedQuarter: number;
	TotalRequiredByEndOfCurrentGradeLevel: number;
	TotalRequiredByGraduation: number;
	DisplayOrder: number;
}

interface StudentAtAGlanceQuery {
	GradRequirement: string;
	GradRequirementGroup: string;
	EarnedGradCredits: number;
	CreditValueRequired: number;
	CreditValueRemaining: number;
	TotalGradCredits: number;
	TotalCreditsRequired: number;
	TotalCreditsRemaining: number;
	DisplayOrder: number;
}

interface StudentCourseCreditsQuery {
	CourseDetails: string;
	SchoolYearWhenTaken: string;
	Term: string;
	GradeDetails: string;
	CreditsContributedByCourse: number;
	GradRequirement: string;
	Status: string;
	DisplayOrder: number;
}

export default class StudentService {
	private db: sql.ConnectionPool;

	constructor(db: sql.ConnectionPool) {
		this.db = db;
	}

	async getGradeBreakdownForStudent(
		studentUniqueId: string
	): Promise<StudentGradeBreakdownResponse> {
		const { recordset } = await this.db.query<StudentGradeBreakdownQuery>`SELECT GradRequirement,
			EarnedGradCredits,
			RemainingCreditsRequiredByLastGradedQuarter,
			RemainingCreditsRequiredByEndOfCurrentGradeLevel,
			RemainingCreditsRequiredByGraduation,
			DifferentialRemainingCreditsRequiredByGraduation,
			SUM(EarnedGradCredits) OVER () as TotalGradCredits,
			SUM(RemainingCreditsRequiredByLastGradedQuarter) OVER () as TotalRequiredByLastGradedQuarter,
			SUM(RemainingCreditsRequiredByEndOfCurrentGradeLevel) OVER () as TotalRequiredByEndOfCurrentGradeLevel,
			SUM(RemainingCreditsRequiredByGraduation) OVER () as TotalRequiredByGraduation,
			DisplayOrder
		FROM [gradCredits].GetStudentChartData(${studentUniqueId})
		ORDER BY DisplayOrder`;

		const items = recordset.map(item => {
			const {
				TotalGradCredits,
				TotalRequiredByLastGradedQuarter,
				TotalRequiredByEndOfCurrentGradeLevel,
				TotalRequiredByGraduation,
				...rest
			} = item;

			return rest;
		});

		return {
			TotalGradCredits: isEmpty(recordset) ? 0 : recordset[0].TotalGradCredits,
			TotalRequiredByLastGradedQuarter: isEmpty(recordset)
				? 0
				: recordset[0].TotalRequiredByLastGradedQuarter,
			TotalRequiredByEndOfCurrentGradeLevel: isEmpty(recordset)
				? 0
				: recordset[0].TotalRequiredByEndOfCurrentGradeLevel,
			TotalRequiredByGraduation: isEmpty(recordset) ? 0 : recordset[0].TotalRequiredByGraduation,
			Items: items
		};
	}

	async getAtAGlanceForStudent(studentUniqueId: string): Promise<StudentAtAGlanceResponse> {
		const { recordset } = await this.db.query<StudentAtAGlanceQuery>`SELECT GradRequirement,
			GradRequirementGroup,
			EarnedGradCredits,
			CreditValueRequired,
			CreditValueRemaining,
			SUM(EarnedGradCredits) OVER () as TotalGradCredits,
			SUM(CreditValueRequired) OVER () as TotalCreditsRequired,
			SUM(CreditValueRemaining) OVER () as TotalCreditsRemaining,
			DisplayOrder
		FROM [gradCredits].GetStudentChartData(${studentUniqueId})
		ORDER BY DisplayOrder`;

		if (recordset.length === 0) {
			return {
				TotalGradCredits: 0,
				TotalCreditsRequired: 0,
				TotalCreditsRemaining: 0,
				Items: []
			};
		}

		const byGroup = groupBy(recordset, item => item.GradRequirementGroup);

		const items = Object.entries(byGroup).map(([groupName, list]) => {
			const reqs = list.map(
				({
					GradRequirementGroup,
					TotalGradCredits,
					TotalCreditsRemaining,
					TotalCreditsRequired,
					...rest
				}) => rest
			);

			return {
				GradRequirementGroup: groupName,
				GradRequirements: reqs
			};
		});

		return {
			TotalGradCredits: recordset[0].TotalGradCredits,
			TotalCreditsRequired: recordset[0].TotalCreditsRequired,
			TotalCreditsRemaining: recordset[0].TotalCreditsRemaining,
			Items: items
		};
	}

	async getStudentData(studentUniqueId: string): Promise<StudentDataResponse | null> {
		const { recordset } = await this.db.query<StudentDataResponse>`SELECT StudentName,
			TotalEarnedCredits,
			TotalEarnedGradCredits,
			CurrentGradeLevel,
			LastGradedQuarter,
			CreditDeficiencyStatus
		FROM [gradCredits].GetStudentData(${studentUniqueId})`;

		return isEmpty(recordset) ? null : recordset[0];
	}

	async getCourseCredits(studentUniqueId: string): Promise<StudentCourseCreditResponse> {
		const { recordset } = await this.db.query<StudentCourseCreditsQuery>`SELECT CourseDetails,
			SchoolYearWhenTaken,
			Term,
			GradeDetails,
			CreditsContributedByCourse,
			GradRequirement,
			Status,
			DisplayOrder
		FROM [gradCredits].GetStudentChartDataGrades(${studentUniqueId})
		ORDER BY DisplayOrder`;

		if (isEmpty(recordset)) {
			return {
				Items: []
			};
		}

		const byYear = groupBy(recordset, item => item.SchoolYearWhenTaken);

		// TEMPORARY
		if (byYear.null) {
			byYear['N/A'] = byYear.null;
			delete byYear.null;
		}

		const byYearGrade = Object.entries(byYear).map(([year, list]) => {
			const byGrade = groupBy(list, item => item.GradeDetails);

			if (byGrade.null) {
				byGrade['N/A'] = byGrade.null;
				delete byGrade.null;
			}

			const details = Object.entries(byGrade).map(([grade, courses]) => ({
				Grade: grade,
				Courses: courses.map(({ SchoolYearWhenTaken, GradeDetails, Term, ...rest }) => ({
					...rest,
					...((SchoolYearWhenTaken === 'N/A' || SchoolYearWhenTaken === null) && {
						Status: 'Courses Not Taken Yet'
					})
				}))
			}));

			return {
				SchoolYear: year,
				GradeDetails: details
			};
		});

		return {
			Items: byYearGrade
		};
	}
}

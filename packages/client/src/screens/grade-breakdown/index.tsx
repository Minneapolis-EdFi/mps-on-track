/* eslint-disable react/jsx-key */
// ^ This is returned from react-table, but eslint isn't picking it up

import React, { FC, useMemo } from 'react';
import { observer } from 'mobx-react-lite';
import { useTable, useExpanded, Column } from 'react-table';
import { flatMap, uniq } from 'lodash-es';

import { StudentGradeBreakdownResponse, StudentCourseCreditResponse } from '@mps/api';
import { useStores } from '../../stores';
import { Async, uniqueIdRandom } from '../../utilities';
import { Spinner, DataTable } from '../../components';

import './grade-breakdown.css';

interface GradeTableProps {
	data: StudentGradeBreakdownResponse;
}

interface StudentCourseCreditsProps {
	data: StudentCourseCreditResponse;
}

const GradeTable: FC<GradeTableProps> = observer(({ data }: GradeTableProps) => {
	return (
		<DataTable
			cols={[
				{ id: 'GradRequirement', title: '' },
				{ id: 'EarnedGradCredits', title: 'Earned Credits' },
				{
					id: 'RemainingCreditsRequiredByLastGradedQuarter',
					title: 'Remaining Credits by Last Graded Quarter'
				},
				{
					id: 'RemainingCreditsRequiredByEndOfCurrentGradeLevel',
					title: 'Remaining Credits by End of Current Grade Level'
				},
				{ id: 'RemainingCreditsRequiredByGraduation', title: 'Remaining Credits by Graduation' }
			]}
			summarize={_data => {
				return [
					{
						id: uniqueIdRandom(),
						values: [
							{ id: 'GradRequirement', value: 'Total' },
							{
								id: 'EarnedGradCredits',
								value: data.TotalGradCredits
							},
							{
								id: 'RemainingCreditsRequiredByLastGradedQuarter',
								value: data.TotalRequiredByLastGradedQuarter
							},
							{
								id: 'RemainingCreditsRequiredByEndOfCurrentGradeLevel',
								value: data.TotalRequiredByEndOfCurrentGradeLevel
							},
							{
								id: 'RemainingCreditsRequiredByGraduation',
								value: data.TotalRequiredByGraduation
							}
						]
					}
				];
			}}
			data={data.Items}
			idProp={row => row.GradRequirement}
		/>
	);
});

interface Item {
	name: string;
	type: 'schoolYear' | 'grade' | 'courseDetail';
	[key: string]: any;
}

const Table = ({ columns, data }: { columns: any; data: Item[] }) => {
	const {
		getTableProps,
		getTableBodyProps,
		headerGroups,
		rows,
		prepareRow,
		state: { expanded }
	} = useTable(
		{
			columns,
			data: data
		},
		useExpanded // Use the useExpanded plugin hook
	);

	const styleRow = ({ type }: Item) => {
		const classes = {
			schoolYear: 'course-credits-school-year',
			grade: 'course-credits-grade',
			courseDetail: 'course-credits-course-detail'
		};
		return classes[type];
	};

	return (
		<table {...getTableProps()} className="data-table">
			<thead>
				{headerGroups.map(headerGroup => (
					<tr {...headerGroup.getHeaderGroupProps()}>
						{headerGroup.headers.map(column => (
							<th {...column.getHeaderProps()}>{column.render('Header')}</th>
						))}
					</tr>
				))}
			</thead>
			<tbody {...getTableBodyProps()}>
				{rows.map(row => {
					prepareRow(row);
					return (
						<tr {...row.getRowProps()} className={styleRow(row.original)}>
							{row.cells.map(cell => {
								return <td {...cell.getCellProps()}>{cell.render('Cell')}</td>;
							})}
						</tr>
					);
				})}
			</tbody>
		</table>
	);
};

const StudentCourseCredits: FC<StudentCourseCreditsProps> = observer(
	({ data }: StudentCourseCreditsProps) => {
		const tableData: Item[] = data.Items.reduce((acc, cur) => {
			const gradeDetails = cur.GradeDetails.reduce((gradeAcc, gradeCur) => {
				const courses: Item[] = gradeCur.Courses.map(({ CourseDetails, ...rest }) => ({
					name: CourseDetails,
					...rest,
					type: 'courseDetail'
				}));

				const grade: Item = {
					name: gradeCur.Grade,
					type: 'grade',
					subRows: courses
				};

				return [...gradeAcc, grade];
			}, [] as any);

			const schoolYear: Item = {
				name: cur.SchoolYear,
				type: 'schoolYear',
				subRows: gradeDetails
			};

			return [...acc, schoolYear];
		}, [] as any);

		// const gradRequirementCols = tableData.reduce((acc, sy) => {
		// 	const l1 = flatMap(sy.subRows, (r: Item) => r.subRows);
		// 	return [...acc, ...l1];
		// }, [] as any);

		const statusSort = [
			'Counts',
			'Does not count: Course Sequence Not Found',
			'Does not count: Course Not Passed',
			'Counts: Course Not Passed',
			'Courses Not Taken Yet'
		];

		const foundStatuses = uniq(
			tableData
				.reduce((acc, sy) => {
					const l1 = flatMap(sy.subRows, r => r.subRows);
					return [...acc, ...l1];
				}, [] as Item[])
				.map(el => el.Status)
		);

		const statuses = statusSort.filter(el => foundStatuses.includes(el));

		const columns = useMemo(() => {
			const cols: Column[] = [
				{
					Header: () => null,
					id: 'expander',
					Cell: function Expander({ row }) {
						if (!row.canExpand) {
							return null;
						}

						const expandedToggleProps = row.getExpandedToggleProps({
							style: {
								paddingLeft: `${row.depth}rem`
							}
						});

						return (
							<span {...expandedToggleProps}>
								{row.isExpanded ? (
									<button className="expand-btn">-</button>
								) : (
									<button className="expand-btn">+</button>
								)}
							</span>
						);
					}
				},
				{
					Header: () => null,
					accessor: 'name'
				},
				{
					Header: 'Counts',
					accessor: 'CourseCreditsReported'
				},
				{
					Header: 'Grad Requirement',
					accessor: 'GradRequirement'
				},
				// {
				// 	Header: 'Grad Requirement',
				// 	columns: uniqBy<Item>(gradRequirementCols, c => c.GradRequirement).map((c: Item) => ({
				// 		Header: c.GradRequirement,
				// 		accessor: c.GradRequirement
				// 	}))
				// },
				{
					Header: 'Status',
					accessor: 'Status'
				}
			];

			return cols;
		}, []);

		return (
			<>
				<h2 className="font-bold text-lg">Courses with Credits Breakdown</h2>
				<Table columns={columns} data={tableData} />
			</>
		);
	}
);

const StudentGradeBreakdown: FC = observer(() => {
	const { reportStore } = useStores();

	return (
		<>
			<Async
				promiseFn={reportStore.getStudentGradeBreakdown}
				pending={() => <Spinner />}
				rejected={(err: Error) => <div>Oops! {err}</div>}
				fulfilled={(resp: any) => <GradeTable data={resp.data} />}
			/>
			<Async
				promiseFn={reportStore.getStudentCourseCredits}
				pending={() => <Spinner />}
				rejected={(err: Error) => <div>Oops! {err}</div>}
				fulfilled={(resp: any) => <StudentCourseCredits data={resp.data} />}
			/>
		</>
	);
});

export default StudentGradeBreakdown;

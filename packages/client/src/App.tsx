import React, { FC, useState } from 'react';
import { configure } from 'mobx';
import { Tabs, TabList, Tab, TabPanels, TabPanel } from '@reach/tabs';

import { GradRequirements, GradeBreakdown, AtAGlance } from './screens';
import { useOnMount, isIE } from './utilities';
import api from './api';
import { useStores } from './stores';
import { ApiResponse } from '@mps/api';

// don't allow state modifications outside actions
configure({ enforceActions: 'observed' });

api.registerBadRequestHandler((resp: ApiResponse<any>) => {
	if ('message' in resp) {
		alert(resp.message);
	}
	if ('errors' in resp) {
		resp.errors.forEach(err => console.error(err.message));
	}
});

const App: FC = () => {
	const { reportStore } = useStores();
	const [hasToken, setHasToken] = useState(false);
	const [hasStudent, setHasStudent] = useState(false);

	const isProd = process.env.APP_ENV && /^prod/i.test(process.env.APP_ENV);

	useOnMount(() => {
		const params = new URLSearchParams(window.location.search);
		const token = params.get('token');
		const student = params.get('studentUniqueId');

		if (token !== null) {
			api.setBearerToken(token);
			setHasToken(true);
		}

		if (student !== null) {
			reportStore.setStudent(student);
			setHasStudent(true);
		}
	});

	if (!hasToken) {
		return <div>No authorization token found</div>;
	}

	if (!hasStudent) {
		return <div>No student ID specified</div>;
	}

	return (
		<div className="flex flex-col min-h-full min-w-md font-sans text-sm">
			{/* Change `w-full` to `container` to look good outside the 800px-wide dashboard */}
			<div className="w-full mx-auto flex-1 px-2 md:px-8 mt-4">
				<Tabs>
					<TabList>
						<Tab>Grad Path Visualization</Tab>
						<Tab>Student Credit Breakdown</Tab>
						<Tab>At a Glance</Tab>
					</TabList>

					<TabPanels>
						<TabPanel>
							<GradRequirements />
						</TabPanel>
						<TabPanel>
							<GradeBreakdown />
						</TabPanel>
						<TabPanel>
							<AtAGlance />
						</TabPanel>
					</TabPanels>
				</Tabs>
			</div>

			{!isProd && !isIE && (
				<footer className="bg-gray-800 mt-4 px-2">
					<code className="text-white mr-4">
						You must complete your My Life Plan requirement. If you have not completed this, please speak with your counselor.
					</code>
				</footer>
			)}
		</div>
	);
};

export default App;

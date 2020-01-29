import findUp from 'find-up';

import { debug } from './log';

/**
 * Take values found in config file and add them to process.env
 */
export const getConfig = () => {
	const filename = 'ontrack.config.json';

	const configFile = findUp.sync(filename, {
		cwd: __dirname
	});

	if (configFile === undefined) {
		throw new Error(`config file ${filename} not found!`);
	}

	debug(`found config file: ${configFile}`);

	const config = require(configFile);

	const configVals = Object.entries(config).reduce((acc, [k, v]) => {
		// prefer preset env vars, otherwise use default env
		acc[k] = process.env[k] || v;
		return acc;
	}, {} as any);

	Object.assign(process.env, configVals);

	return configVals;
};

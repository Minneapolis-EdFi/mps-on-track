import { debug } from './log';
import { getConfig } from './get-config';

debug('getting config');

// add config values to process.env
const foundConfig = getConfig();

debug(`config found: ${JSON.stringify(foundConfig)}`);

import Server from './server';
import { connect } from './db-connect';
import controllers from './controllers';

async function main() {
	try {
		const pool = await connect();

		const server = new Server(controllers.map(Controller => new Controller(pool)));

		server.listen();
	} catch (err) {
		console.error(err);
		process.exit(1);
	}
}

main();

// Export types
export * from './models';

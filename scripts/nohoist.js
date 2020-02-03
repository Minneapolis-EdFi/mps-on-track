const path = require('path');
const fs = require('fs');

const NOHOIST_ARR = ['@mps/api/**'];

const args = process.argv.slice(2);

const packageFile = path.join(__dirname, '../package.json');

let package = require(packageFile);

if (args[0] === 'add') {
	package.workspaces.nohoist = NOHOIST_ARR;
} else if (args[0] === 'remove') {
	delete package.workspaces.nohoist;
} else {
	console.error('expected argument of "add" or "remove"');
	process.exit(1);
}

const out = JSON.stringify(package, null, 2);

fs.writeFileSync(packageFile, out);

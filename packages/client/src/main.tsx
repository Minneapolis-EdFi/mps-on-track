import React, { lazy, Suspense } from 'react';
import ReactDOM from 'react-dom';

import { Spinner } from './components';

import './styles/main.css';

// We have to lazy-load the app, or things get initialized before polyfills have loaded
const App = lazy(() => import(/* webpackChunkName: 'app' */ './App'));

// Ironically, Webpack's dynamic import relies on promises, which underlie `await`, so we
// conditionally load a promise polyfill in index.html.

const loadPolyfills = async () => {
	// prettier-ignore
	const isNewBrowser = ('assign' in Object);

	if (!isNewBrowser) {
		return await import(/* webpackChunkName: 'polyfill' */ './polyfill');
	} else {
		return Promise.resolve();
	}
};

loadPolyfills().then(() => {
	ReactDOM.render(
		<Suspense fallback={<Spinner />}>
			<App />
		</Suspense>,
		document.getElementById('app')
	);
});

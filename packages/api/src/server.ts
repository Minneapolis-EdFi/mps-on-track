import express, { Router } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import bodyParser from 'body-parser';
import compression from 'compression';
import expressJwt from 'express-jwt';
import winston from 'winston';
import expressWinston from 'express-winston';

import { Controller } from './interfaces';
import { errorHandlingMiddleware } from './middleware';

const PORT = process.env.API_PORT || 4000;
const JWT_SECRET = process.env.JWT_SECRET;

export default class Server {
	public app: express.Application;

	constructor(controllers: Controller[]) {
		this.app = express();

		winston.loggers.add('serverside', {
			transports: [
				new winston.transports.Console({
					level: 'info'
				})
				// new winston.transports.File({
				// 	filename: 'test-log.log',
				// 	level: 'info'
				// })
			]
		});

		this.initializeSecurity();
		this.initializeMiddlewares();
		this.initializeAuthentication();
		this.initializeControllers(controllers);
		this.initializeErrorHandling();
	}

	public listen() {
		this.app.listen(PORT, () => {
			console.log(`Server ready at http://localhost:${PORT}`);
		});
	}

	private initializeSecurity() {
		this.app.use(helmet());
	}

	private initializeMiddlewares() {
		this.app.use(cors());
		this.app.use(bodyParser.json());
		this.app.use(compression());
		this.app.use(
			expressWinston.logger({
				winstonInstance: winston.loggers.get('serverside'),
				meta: true,
				requestWhitelist: ['url', 'headers', 'method', 'query', 'user']
			})
		);
	}

	private initializeAuthentication() {
		this.app.use(
			expressJwt({
				secret: JWT_SECRET as string
			}).unless({
				path: ['/api', '/api/health']
			})
		);
	}

	private initializeControllers(controllers: Controller[]) {
		const apiRoutes = Router();

		controllers.forEach(controller => {
			apiRoutes.use('/', controller.router);
		});

		this.app.use('/api', apiRoutes);
	}

	private initializeErrorHandling() {
		// register route middleware to return nice errors instead of JS stacktraces
		this.app.use(errorHandlingMiddleware);

		this.app.use(
			expressWinston.errorLogger({
				transports: [
					new winston.transports.Console({})
					// new winston.transports.File({
					// 	filename: 'test-err.log'
					// })
				]
			})
		);
	}
}
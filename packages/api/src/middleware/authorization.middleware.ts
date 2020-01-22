import { RequestHandler } from 'express';

export type AuthzMiddleware = (idParam: string) => RequestHandler;

/**
 * Forbid users from requesting records for a different student than what's in their token
 */
const authorizationMiddleware: AuthzMiddleware = (idParam: string) => (req, res, next) => {
	if (req.user.studentUniqueId !== req.params[idParam]) {
		res.status(403).json('Unauthorized');
	} else {
		next();
	}
};

export default authorizationMiddleware;

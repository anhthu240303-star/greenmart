const { check, validationResult } = require('express-validator');
const ApiResponse = require('../utils/response');

const validate = (req, res, next) => {
	const errors = validationResult(req);
	if (!errors.isEmpty()) {
		return ApiResponse.badRequest(res, 'Dữ liệu không hợp lệ', errors.array());
	}
	next();
};


const login = [
	check('email').notEmpty().withMessage('email là bắt buộc').isEmail().withMessage('email không hợp lệ'),
	check('password').notEmpty().withMessage('password là bắt buộc'),
	validate,
];

module.exports = {
	login,
};

const { check, validationResult } = require('express-validator');
const ApiResponse = require('../utils/response');

const validate = (req, res, next) => {
	const errors = validationResult(req);
	if (!errors.isEmpty()) {
		return ApiResponse.badRequest(res, 'Dữ liệu không hợp lệ', errors.array());
	}
	next();
};

const register = [
	check('username')
		.notEmpty()
		.withMessage('username là bắt buộc')
		.isLength({ min: 3, max: 50 })
		.withMessage('username phải từ 3 đến 50 ký tự'),
	check('email').notEmpty().withMessage('email là bắt buộc').isEmail().withMessage('email không hợp lệ'),
	check('password')
		.notEmpty()
		.withMessage('password là bắt buộc')
		.isLength({ min: 6 })
		.withMessage('password phải có ít nhất 6 ký tự'),
	check('fullName').notEmpty().withMessage('fullName là bắt buộc'),
	check('phone')
		.optional()
		.matches(/^[0-9]{10,11}$/)
		.withMessage('Số điện thoại không hợp lệ'),
	validate,
];

const login = [
	check('email').notEmpty().withMessage('email là bắt buộc').isEmail().withMessage('email không hợp lệ'),
	check('password').notEmpty().withMessage('password là bắt buộc'),
	validate,
];

module.exports = {
	register,
	login,
};

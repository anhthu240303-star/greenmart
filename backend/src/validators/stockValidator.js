const { check, validationResult } = require('express-validator');
const ApiResponse = require('../utils/response');

const validate = (req, res, next) => {
	const errors = validationResult(req);
	if (!errors.isEmpty()) {
		return ApiResponse.badRequest(res, 'Dữ liệu không hợp lệ', errors.array());
	}
	next();
};

const createStockIn = [
	check('supplier').notEmpty().withMessage('Nhà cung cấp là bắt buộc').isMongoId(),
	check('items').isArray({ min: 1 }).withMessage('Cần ít nhất 1 item'),
	check('items.*.product').notEmpty().isMongoId().withMessage('Product invalid'),
	check('items.*.quantity').notEmpty().isInt({ min: 1 }).withMessage('Quantity phải >= 1'),
	check('items.*.unitPrice').exists().isFloat({ min: 0 }).withMessage('UnitPrice phải >= 0'),
	validate,
];

const createStockOut = [
	check('type')
		.notEmpty()
		.withMessage('Type là bắt buộc')
		.isIn(['sale', 'internal_use', 'damaged', 'expired', 'return_to_supplier', 'other'])
		.withMessage('Type không hợp lệ'),
	check('items').isArray({ min: 1 }).withMessage('Cần ít nhất 1 item'),
	check('items.*.product').notEmpty().isMongoId().withMessage('Product invalid'),
	check('items.*.quantity').notEmpty().isInt({ min: 1 }).withMessage('Quantity phải >= 1'),
	check('items.*.unitPrice').exists().isFloat({ min: 0 }).withMessage('UnitPrice phải >= 0'),
	check('reason').notEmpty().withMessage('Reason là bắt buộc'),
	validate,
];

module.exports = { createStockIn, createStockOut };

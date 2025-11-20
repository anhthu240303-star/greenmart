const { check, validationResult } = require('express-validator');
const ApiResponse = require('../utils/response');

const validate = (req, res, next) => {
	const errors = validationResult(req);
	if (!errors.isEmpty()) {
		return ApiResponse.badRequest(res, 'Dữ liệu không hợp lệ', errors.array());
	}
	next();
};

const createProduct = [
	check('sku').notEmpty().withMessage('SKU là bắt buộc').isLength({ max: 50 }),
	check('name').notEmpty().withMessage('Tên sản phẩm là bắt buộc').isLength({ max: 200 }),
	check('category').notEmpty().withMessage('Danh mục là bắt buộc').isMongoId().withMessage('Category không hợp lệ'),
	check('unit').optional().isString(),
	check('costPrice').notEmpty().withMessage('Giá vốn là bắt buộc').isFloat({ min: 0 }).withMessage('Giá vốn phải >= 0'),
	check('sellingPrice').notEmpty().withMessage('Giá bán là bắt buộc').isFloat({ min: 0 }).withMessage('Giá bán phải >= 0'),
	check('currentStock').optional().isInt({ min: 0 }).withMessage('Số lượng tồn phải >= 0'),
	check('minStock').optional().isInt({ min: 0 }),
	check('maxStock').optional().isInt({ min: 0 }),
	validate,
];

const updateProduct = [
	check('sku').optional().isLength({ max: 50 }),
	check('name').optional().isLength({ max: 200 }),
	check('category').optional().isMongoId().withMessage('Category không hợp lệ'),
	check('costPrice').optional().isFloat({ min: 0 }).withMessage('Giá vốn phải >= 0'),
	check('sellingPrice').optional().isFloat({ min: 0 }).withMessage('Giá bán phải >= 0'),
	check('currentStock').optional().isInt({ min: 0 }).withMessage('Số lượng tồn phải >= 0'),
	validate,
];

module.exports = { createProduct, updateProduct };

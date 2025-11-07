const Category = require('../models/Category');
const Product = require('../models/Product');
const ApiResponse = require('../utils/response');
const { uploadToCloudinary, deleteFromCloudinary } = require('../config/cloudinary');

/**
 * @desc    Tạo danh mục mới
 * @route   POST /api/categories
 * @access  Private (Admin, Warehouse Manager)
 */
const createCategory = async (req, res) => {
  try {
    const { name, code, description } = req.body;

    // Kiểm tra trùng mã danh mục
    const existingCategory = await Category.findOne({
      $or: [{ name: name.trim() }, { code: code.toUpperCase() }],
    });

    if (existingCategory) {
      return ApiResponse.badRequest(res, 'Tên hoặc mã danh mục đã tồn tại');
    }

    const category = await Category.create({
      name: name.trim(),
      code: code.toUpperCase(),
      description,
      createdBy: req.user._id,
    });

    await category.populate('createdBy', 'fullName email');

    return ApiResponse.created(res, { category }, 'Tạo danh mục thành công');
  } catch (error) {
    console.error('Create category error:', error);
    return ApiResponse.error(res, error.message);
  }
};

/**
 * @desc    Lấy danh sách danh mục (có phân trang, tìm kiếm)
 * @route   GET /api/categories
 * @access  Private
 */
const getCategories = async (req, res) => {
  try {
    const {
      page = 1,
      limit = 10,
      search,
      isActive,
      sortBy = 'createdAt',
      sortOrder = 'desc',
    } = req.query;

    const query = {};

    // Tìm kiếm theo tên hoặc mã
    if (search) {
      query.$or = [
        { name: { $regex: search, $options: 'i' } },
        { code: { $regex: search, $options: 'i' } },
        { description: { $regex: search, $options: 'i' } },
      ];
    }

    // Lọc theo trạng thái hoạt động
    if (isActive !== undefined) {
      query.isActive = isActive === 'true';
    }

    const skip = (page - 1) * limit;
    const sort = { [sortBy]: sortOrder === 'desc' ? -1 : 1 };

    const categories = await Category.find(query)
      .populate('createdBy', 'fullName email')
      .sort(sort)
      .skip(skip)
      .limit(parseInt(limit));

    // Đếm số sản phẩm trong mỗi danh mục
    const categoriesWithCount = await Promise.all(
      categories.map(async (category) => {
        const productCount = await Product.countDocuments({
          category: category._id,
        });
        return { ...category.toObject(), productCount };
      })
    );

    const total = await Category.countDocuments(query);

    return ApiResponse.paginate(
      res,
      categoriesWithCount,
      {
        page: parseInt(page),
        limit: parseInt(limit),
        total,
      },
      'Lấy danh sách danh mục thành công'
    );
  } catch (error) {
    console.error('Get categories error:', error);
    return ApiResponse.error(res, error.message);
  }
};

/**
 * @desc    Lấy tất cả danh mục (không phân trang)
 * @route   GET /api/categories/all
 * @access  Private
 */
const getAllCategories = async (req, res) => {
  try {
    const categories = await Category.find({ isActive: true })
      .select('_id name code')
      .sort({ name: 1 });

    return ApiResponse.success(
      res,
      { categories, count: categories.length },
      'Lấy danh sách danh mục thành công'
    );
  } catch (error) {
    console.error('Get all categories error:', error);
    return ApiResponse.error(res, error.message);
  }
};

/**
 * @desc    Lấy chi tiết danh mục
 * @route   GET /api/categories/:id
 * @access  Private
 */
const getCategoryById = async (req, res) => {
  try {
    const category = await Category.findById(req.params.id).populate(
      'createdBy',
      'fullName email'
    );

    if (!category) {
      return ApiResponse.notFound(res, 'Không tìm thấy danh mục');
    }

    const productCount = await Product.countDocuments({
      category: category._id,
    });

    return ApiResponse.success(
      res,
      { category: { ...category.toObject(), productCount } },
      'Lấy thông tin danh mục thành công'
    );
  } catch (error) {
    console.error('Get category by ID error:', error);
    return ApiResponse.error(res, error.message);
  }
};

/**
 * @desc    Cập nhật danh mục
 * @route   PUT /api/categories/:id
 * @access  Private (Admin, Warehouse Manager)
 */
const updateCategory = async (req, res) => {
  try {
    const category = await Category.findById(req.params.id);
    if (!category) {
      return ApiResponse.notFound(res, 'Không tìm thấy danh mục');
    }

    const { name, code, description, isActive } = req.body;

    // Kiểm tra mã danh mục nếu thay đổi
    if (code && code.toUpperCase() !== category.code) {
      const existingCategory = await Category.findOne({
        code: code.toUpperCase(),
      });
      if (existingCategory) {
        return ApiResponse.badRequest(res, 'Mã danh mục đã tồn tại');
      }
      category.code = code.toUpperCase();
    }

    if (name) category.name = name.trim();
    if (description !== undefined) category.description = description;
    if (isActive !== undefined) category.isActive = isActive;

    await category.save();
    await category.populate('createdBy', 'fullName email');

    return ApiResponse.updated(res, { category }, 'Cập nhật danh mục thành công');
  } catch (error) {
    console.error('Update category error:', error);
    return ApiResponse.error(res, error.message);
  }
};

/**
 * @desc    Xóa danh mục (chỉ khi không có sản phẩm liên quan)
 * @route   DELETE /api/categories/:id
 * @access  Private (Admin, Warehouse Manager)
 */
const deleteCategory = async (req, res) => {
  try {
    const category = await Category.findById(req.params.id);
    if (!category) {
      return ApiResponse.notFound(res, 'Không tìm thấy danh mục');
    }

    const productCount = await Product.countDocuments({
      category: category._id,
    });

    if (productCount > 0) {
      return ApiResponse.badRequest(
        res,
        `Không thể xóa danh mục này vì có ${productCount} sản phẩm đang sử dụng`
      );
    }

    // Xóa ảnh nếu có
    if (category.image?.publicId) {
      await deleteFromCloudinary(category.image.publicId);
    }

    await category.deleteOne();

    return ApiResponse.deleted(res, 'Xóa danh mục thành công');
  } catch (error) {
    console.error('Delete category error:', error);
    return ApiResponse.error(res, error.message);
  }
};

/**
 * @desc    Upload ảnh danh mục
 * @route   POST /api/categories/:id/image
 * @access  Private (Admin, Warehouse Manager)
 */
const uploadCategoryImage = async (req, res) => {
  try {
    const category = await Category.findById(req.params.id);
    if (!category) {
      return ApiResponse.notFound(res, 'Không tìm thấy danh mục');
    }

    if (!req.file) {
      return ApiResponse.badRequest(res, 'Vui lòng chọn ảnh để upload');
    }

    // Xóa ảnh cũ nếu có
    if (category.image?.publicId) {
      await deleteFromCloudinary(category.image.publicId);
    }

    // Upload ảnh mới lên Cloudinary
    const b64 = Buffer.from(req.file.buffer).toString('base64');
    const dataURI = `data:${req.file.mimetype};base64,${b64}`;
    const result = await uploadToCloudinary(dataURI, 'greenmart/categories');

    category.image = {
      url: result.url,
      publicId: result.publicId,
    };

    await category.save();

    return ApiResponse.success(res, { category }, 'Upload ảnh thành công');
  } catch (error) {
    console.error('Upload category image error:', error);
    return ApiResponse.error(res, error.message);
  }
};

module.exports = {
  createCategory,
  getCategories,
  getAllCategories,
  getCategoryById,
  updateCategory,
  deleteCategory,
  uploadCategoryImage,
};

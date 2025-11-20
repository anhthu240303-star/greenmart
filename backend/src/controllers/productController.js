const mongoose = require('mongoose');
const Product = require('../models/Product');
const Category = require('../models/Category');
const BatchLot = require('../models/BatchLot');
const ApiResponse = require('../utils/response');
const { uploadToCloudinary, deleteFromCloudinary } = require('../config/cloudinary');
const { logActivity } = require('../utils/activityLogger');

/**
 * @desc    Tạo sản phẩm mới
 * @route   POST /api/products
 * @access  Private/Admin/Manager
 */
const createProduct = async (req, res) => {
  try {
    const {
      name,
      description,
      category,
      unit,
      costPrice,
      sellingPrice,
      barcode,
      location,
      defaultSupplier,
      currentStock,
      minStock,
    } = req.body;

    // Kiểm tra danh mục tồn tại
    const categoryExists = await Category.findById(category);
    if (!categoryExists) {
      return ApiResponse.notFound(res, 'Danh mục không tồn tại');
    }

    // Tạo sản phẩm
    const product = await Product.create({
      name,
      description,
      category,
      unit,
      costPrice,
      sellingPrice,
      barcode,
      location,
      defaultSupplier,
      currentStock: currentStock || 0,
      minStock: minStock || 10,
      createdBy: req.user._id,
    });

    // Populate thông tin liên quan
    await product.populate([
      { path: 'category', select: 'name code' },
      { path: 'defaultSupplier', select: 'name code' },
      { path: 'createdBy', select: 'fullName email' },
    ]);

    // Log activity: create product
    try {
      await logActivity({
        user: req.user && req.user._id,
        action: 'create_product',
        entityType: 'Product',
        entityId: product._id,
        description: `Tạo sản phẩm ${product.name}`,
        meta: { name: product.name, productId: product._id },
      });
    } catch (_) {}

    return ApiResponse.created(res, { product }, 'Tạo sản phẩm thành công');
  } catch (error) {
    console.error('Create product error:', error);
    return ApiResponse.error(res, error.message);
  }
};

/**
 * @desc    Lấy danh sách sản phẩm
 * @route   GET /api/products
 * @access  Private
 */
const getProducts = async (req, res) => {
  try {
    const {
      page = 1,
      limit = 10,
      search,
      category,
      status,
      outOfStock,
      sortBy = 'createdAt',
      sortOrder = 'desc',
    } = req.query;

    const query = {};

    // Tìm kiếm theo tên hoặc barcode
    if (search) {
      query.$or = [
        { name: { $regex: search, $options: 'i' } },
        { barcode: { $regex: search, $options: 'i' } },
      ];
    }

    if (category) query.category = category;
    if (status) query.status = status;

    if (outOfStock === 'true') {
      query.currentStock = 0;
    }

    const skip = (page - 1) * limit;
    const sort = { [sortBy]: sortOrder === 'desc' ? -1 : 1 };

    const products = await Product.find(query)
      .populate('category', 'name code')
      .populate('defaultSupplier', 'name code')
      .populate('createdBy', 'fullName email')
      .sort(sort)
      .skip(skip)
      .limit(parseInt(limit));

    const total = await Product.countDocuments(query);

    return ApiResponse.paginate(
      res,
      products,
      {
        page: parseInt(page),
        limit: parseInt(limit),
        total,
      },
      'Lấy danh sách sản phẩm thành công'
    );
  } catch (error) {
    console.error('Get products error:', error);
    return ApiResponse.error(res, error.message);
  }
};

/**
 * @desc    Lấy chi tiết sản phẩm
 * @route   GET /api/products/:id
 * @access  Private
 */
const getProductById = async (req, res) => {
  try {
    const product = await Product.findById(req.params.id)
      .populate('category', 'name code description')
      .populate('defaultSupplier', 'name code phone email')
      .populate('createdBy', 'fullName email')
      .populate('updatedBy', 'fullName email');

    if (!product) {
      return ApiResponse.notFound(res, 'Không tìm thấy sản phẩm');
    }

    return ApiResponse.success(res, { product }, 'Lấy thông tin sản phẩm thành công');
  } catch (error) {
    console.error('Get product by ID error:', error);
    return ApiResponse.error(res, error.message);
  }
};

/**
 * @desc    Cập nhật sản phẩm
 * @route   PUT /api/products/:id
 * @access  Private/Admin/Manager
 */
const updateProduct = async (req, res) => {
  try {
    console.log('=== UPDATE PRODUCT ===');
    console.log('Product ID:', req.params.id);
    console.log('Request body:', req.body);
    
    let product = await Product.findById(req.params.id);
    if (!product) {
      return ApiResponse.notFound(res, 'Không tìm thấy sản phẩm');
    }

    const oldSellingPrice = product.sellingPrice;

    const {
      name,
      description,
      category,
      unit,
      costPrice,
      sellingPrice,
      barcode,
      location,
      defaultSupplier,
      status,
      currentStock,
      minStock,
    } = req.body;

    if (category && category !== product.category.toString()) {
      const categoryExists = await Category.findById(category);
      if (!categoryExists) {
        return ApiResponse.notFound(res, 'Danh mục không tồn tại');
      }
    }

    if (name) product.name = name;
    if (description !== undefined) product.description = description;
    if (category) product.category = category;
    if (unit) product.unit = unit;
    if (costPrice !== undefined) product.costPrice = costPrice;
    if (sellingPrice !== undefined) product.sellingPrice = sellingPrice;
    if (barcode !== undefined) product.barcode = barcode;
    if (location) product.location = location;
    if (defaultSupplier) product.defaultSupplier = defaultSupplier;
    if (status) product.status = status;
    if (currentStock !== undefined) product.currentStock = currentStock;
    if (minStock !== undefined) product.minStock = minStock;

    product.updatedBy = req.user._id;
    await product.save();
    
    console.log('Product updated successfully:', product._id);

    // If sellingPrice changed, log activity
    try {
      if (sellingPrice !== undefined && sellingPrice !== oldSellingPrice) {
        await logActivity({
          user: req.user && req.user._id,
          action: 'change_selling_price',
          entityType: 'Product',
          entityId: product._id,
          description: `Thay đổi giá bán cho ${product.name}`,
          meta: { productId: product._id, name: product.name, before: oldSellingPrice, after: sellingPrice },
        });
      }
    } catch (_) {}

    await product.populate([
      { path: 'category', select: 'name code' },
      { path: 'defaultSupplier', select: 'name code' },
      { path: 'updatedBy', select: 'fullName email' },
    ]);

    return ApiResponse.updated(res, { product }, 'Cập nhật sản phẩm thành công');
  } catch (error) {
    console.error('Update product error:', error);
    return ApiResponse.error(res, error.message);
  }
};

/**
 * @desc    Xóa sản phẩm
 * @route   DELETE /api/products/:id
 * @access  Private/Admin/Manager
 */
const deleteProduct = async (req, res) => {
  try {
    const product = await Product.findById(req.params.id);
    if (!product) {
      return ApiResponse.notFound(res, 'Không tìm thấy sản phẩm');
    }

    if (product.images && product.images.length > 0) {
      for (const image of product.images) {
        if (image.publicId) {
          await deleteFromCloudinary(image.publicId);
        }
      }
    }

    await product.deleteOne();
    // Log activity: delete product
    try {
      await logActivity({
        user: req.user && req.user._id,
        action: 'delete_product',
        entityType: 'Product',
        entityId: product._id,
        description: `Xóa sản phẩm ${product.name}`,
        meta: { productId: product._id, name: product.name },
      });
    } catch (_) {}

    return ApiResponse.deleted(res, 'Xóa sản phẩm thành công');
  } catch (error) {
    console.error('Delete product error:', error);
    return ApiResponse.error(res, error.message);
  }
};

/**
 * @desc    Upload ảnh sản phẩm
 * @route   POST /api/products/:id/images
 * @access  Private/Admin/Manager
 */
const uploadProductImages = async (req, res) => {
  try {
    const product = await Product.findById(req.params.id);
    if (!product) {
      return ApiResponse.notFound(res, 'Không tìm thấy sản phẩm');
    }

    if (!req.files || req.files.length === 0) {
      return ApiResponse.badRequest(res, 'Vui lòng chọn ảnh để upload');
    }

    const uploadedImages = [];

    for (const file of req.files) {
      const b64 = Buffer.from(file.buffer).toString('base64');
      const dataURI = `data:${file.mimetype};base64,${b64}`;
      const result = await uploadToCloudinary(dataURI, 'greenmart/products');
      uploadedImages.push({
        url: result.url,
        publicId: result.publicId,
        isPrimary: product.images.length === 0 && uploadedImages.length === 0,
      });
    }

    product.images.push(...uploadedImages);
    await product.save();

    return ApiResponse.success(res, { images: uploadedImages }, 'Upload ảnh thành công');
  } catch (error) {
    console.error('Upload images error:', error);
    return ApiResponse.error(res, error.message);
  }
};

/**
 * @desc    Xóa ảnh sản phẩm
 * @route   DELETE /api/products/:id/images/:imageId
 * @access  Private/Admin/Manager
 */
const deleteProductImage = async (req, res) => {
  try {
    const product = await Product.findById(req.params.id);
    if (!product) {
      return ApiResponse.notFound(res, 'Không tìm thấy sản phẩm');
    }

    const imageIndex = product.images.findIndex(
      (img) => img._id.toString() === req.params.imageId
    );

    if (imageIndex === -1) {
      return ApiResponse.notFound(res, 'Không tìm thấy ảnh');
    }

    const image = product.images[imageIndex];
    if (image.publicId) {
      await deleteFromCloudinary(image.publicId);
    }

    product.images.splice(imageIndex, 1);
    await product.save();

    return ApiResponse.deleted(res, 'Xóa ảnh thành công');
  } catch (error) {
    console.error('Delete image error:', error);
    return ApiResponse.error(res, error.message);
  }
};

/**
 * @desc    Set ảnh chính
 * @route   PUT /api/products/:id/images/:imageId/primary
 * @access  Private/Admin/Manager
 */
const setPrimaryImage = async (req, res) => {
  try {
    const product = await Product.findById(req.params.id);
    if (!product) {
      return ApiResponse.notFound(res, 'Không tìm thấy sản phẩm');
    }

    product.images.forEach((img) => {
      img.isPrimary = img._id.toString() === req.params.imageId;
    });

    await product.save();
    return ApiResponse.success(res, { product }, 'Cập nhật ảnh chính thành công');
  } catch (error) {
    console.error('Set primary image error:', error);
    return ApiResponse.error(res, error.message);
  }
};

/**
 * @desc    Lấy sản phẩm hết hàng
 * @route   GET /api/products/out-of-stock
 * @access  Private
 */
const getOutOfStockProducts = async (req, res) => {
  try {
    const products = await Product.find({ currentStock: 0, status: 'active' })
      .populate('category', 'name code')
      .sort({ name: 1 });

    return ApiResponse.success(
      res,
      { products, count: products.length },
      'Lấy danh sách sản phẩm hết hàng thành công'
    );
  } catch (error) {
    console.error('Get out of stock error:', error);
    return ApiResponse.error(res, error.message);
  }
};

/**
 * @desc    Lấy sản phẩm theo danh mục
 * @route   GET /api/products/category/:categoryId
 * @access  Private
 */
const getProductsByCategory = async (req, res) => {
  try {
    const products = await Product.find({ category: req.params.categoryId })
      .populate('category', 'name code')
      .sort({ name: 1 });

    return ApiResponse.success(
      res,
      { products, count: products.length },
      'Lấy danh sách sản phẩm theo danh mục thành công'
    );
  } catch (error) {
    console.error('Get products by category error:', error);
    return ApiResponse.error(res, error.message);
  }
};

/**
 * @desc    Lấy danh sách lô hàng (batch) còn hàng cho sản phẩm
 * @route   GET /api/products/:id/batches
 * @access  Private
 */
const getProductBatches = async (req, res) => {
  try {
    const productId = req.params.id;
    const onlyActive = req.query.onlyActive !== 'false'; // default true

    const query = { product: productId, remainingQuantity: { $gt: 0 } };
    if (onlyActive) query.status = 'active';

    const batches = await BatchLot.find(query)
      .select('_id batchNumber remainingQuantity initialQuantity costPrice manufacturingDate expiryDate receivedDate status')
      .sort({ receivedDate: 1 }); // FIFO order

    return ApiResponse.success(res, { batches }, 'Lấy danh sách lô hàng thành công');
  } catch (error) {
    console.error('Get product batches error:', error);
    return ApiResponse.error(res, error.message);
  }
};

/**
 * @desc    Lấy danh sách sản phẩm chưa có ảnh
 * @route   GET /api/products/no-images
 * @access  Private
 */
const getProductsWithoutImages = async (req, res) => {
  try {
    // Sản phẩm có trường images không tồn tại hoặc là mảng rỗng
    const products = await Product.find({
      $or: [{ images: { $exists: false } }, { images: { $size: 0 } }],
    })
      .populate('category', 'name code')
      .sort({ name: 1 });

    return ApiResponse.success(res, { products, count: products.length }, 'Lấy danh sách sản phẩm chưa có ảnh thành công');
  } catch (error) {
    console.error('Get products without images error:', error);
    return ApiResponse.error(res, error.message);
  }
};

/**
 * @desc    Lấy giá vốn mới nhất của sản phẩm
 * @route   GET /api/products/cost?product=productId
 * @access  Private
 */
const getProductCost = async (req, res) => {
  try {
    const { product } = req.query;
    if (!product) {
      return ApiResponse.badRequest(res, 'Thiếu thông tin sản phẩm');
    }
    if (!mongoose.Types.ObjectId.isValid(product)) {
      return ApiResponse.badRequest(res, 'Product ID không hợp lệ');
    }
    const prod = await Product.findById(product);
    if (!prod) {
      return ApiResponse.notFound(res, 'Không tìm thấy sản phẩm');
    }
    return ApiResponse.success(res, { costPrice: prod.costPrice });
  } catch (error) {
    try {
      console.error('Get product cost error:', error && error.stack ? error.stack : error);
    } catch (_) {}
    const msg = (process.env.NODE_ENV === 'development' && error && error.message) ? `${error.message}` : 'Có lỗi khi lấy giá vốn sản phẩm';
    return ApiResponse.error(res, msg);
  }
};

/**
 * @desc    Recompute product.currentStock from BatchLot remaining quantities
 * @route   PUT /api/products/:id/recompute-stock
 * @access  Private/Admin/Manager
 */
const recomputeProductStock = async (req, res) => {
  try {
    const productId = req.params.id;
    const agg = await BatchLot.aggregate([
      { $match: { product: new mongoose.Types.ObjectId(productId) } },
      { $group: { _id: '$product', totalRemaining: { $sum: { $ifNull: ['$remainingQuantity', 0] } } } },
    ]);

    const total = (agg && agg.length) ? agg[0].totalRemaining || 0 : 0;
    const product = await Product.findById(productId);
    if (!product) return ApiResponse.notFound(res, 'Không tìm thấy sản phẩm');
    product.currentStock = total;
    await product.save();
    return ApiResponse.success(res, { product }, 'Đã tính lại tồn kho sản phẩm từ lô hàng (batch)');
  } catch (error) {
    console.error('Recompute product stock error:', error);
    return ApiResponse.error(res, error.message);
  }
};

module.exports = {
  createProduct,
  getProducts,
  getProductById,
  updateProduct,
  deleteProduct,
  uploadProductImages,
  deleteProductImage,
  setPrimaryImage,
  getOutOfStockProducts,
  getProductsByCategory,
  getProductsWithoutImages,
  getProductCost,
  getProductBatches,
  recomputeProductStock,
};

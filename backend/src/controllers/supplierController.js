const Supplier = require('../models/Supplier');
const ApiResponse = require('../utils/response');

/**
 * @desc    Tạo nhà cung cấp mới
 * @route   POST /api/suppliers
 * @access  Private (Admin, Warehouse Manager)
 */
const createSupplier = async (req, res) => {
  try {
    const {
      code,
      name,
      contactPerson,
      phone,
      email,
      address,
      taxCode,
      bankAccount,
    } = req.body;

    // Kiểm tra trùng mã nếu có code được gửi lên
    if (code) {
      const upperCode = code.toUpperCase();
      const existingSupplier = await Supplier.findOne({ code: upperCode });
      if (existingSupplier) {
        return ApiResponse.badRequest(res, 'Mã nhà cung cấp đã tồn tại');
      }
    }

    const supplier = await Supplier.create({
      code: code ? code.toUpperCase() : undefined, // Để undefined để middleware tự tạo
      name,
      contactPerson,
      phone,
      email,
      address,
      taxCode,
      bankAccount,
      createdBy: req.user._id,
    });

    await supplier.populate('createdBy', 'fullName email');

    return ApiResponse.created(res, { supplier }, 'Tạo nhà cung cấp thành công');
  } catch (error) {
    console.error('Create supplier error:', error);
    return ApiResponse.error(res, error.message);
  }
};

/**
 * @desc    Lấy danh sách nhà cung cấp
 * @route   GET /api/suppliers
 * @access  Private
 */
const getSuppliers = async (req, res) => {
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

    // Tìm kiếm theo tên, mã, người liên hệ, số điện thoại
    if (search) {
      query.$or = [
        { name: { $regex: search, $options: 'i' } },
        { code: { $regex: search, $options: 'i' } },
        { contactPerson: { $regex: search, $options: 'i' } },
        { phone: { $regex: search, $options: 'i' } },
      ];
    }

    // Lọc theo trạng thái hoạt động
    if (isActive !== undefined) {
      query.isActive = isActive === 'true';
    }

    const skip = (page - 1) * limit;
    const sort = { [sortBy]: sortOrder === 'desc' ? -1 : 1 };

    const suppliers = await Supplier.find(query)
      .populate('createdBy', 'fullName email')
      .sort(sort)
      .skip(skip)
      .limit(parseInt(limit));

    const total = await Supplier.countDocuments(query);

    return ApiResponse.paginate(
      res,
      suppliers,
      { page: parseInt(page), limit: parseInt(limit), total },
      'Lấy danh sách nhà cung cấp thành công'
    );
  } catch (error) {
    console.error('Get suppliers error:', error);
    return ApiResponse.error(res, error.message);
  }
};

/**
 * @desc    Lấy tất cả nhà cung cấp (dạng đơn giản, không phân trang)
 * @route   GET /api/suppliers/all
 * @access  Private
 */
const getAllSuppliers = async (req, res) => {
  try {
    const suppliers = await Supplier.find({ isActive: true })
      .select('_id name code phone')
      .sort({ name: 1 });

    return ApiResponse.success(
      res,
      { suppliers, count: suppliers.length },
      'Lấy danh sách nhà cung cấp thành công'
    );
  } catch (error) {
    console.error('Get all suppliers error:', error);
    return ApiResponse.error(res, error.message);
  }
};

/**
 * @desc    Lấy chi tiết nhà cung cấp
 * @route   GET /api/suppliers/:id
 * @access  Private
 */
const getSupplierById = async (req, res) => {
  try {
    const supplier = await Supplier.findById(req.params.id).populate(
      'createdBy',
      'fullName email'
    );

    if (!supplier) {
      return ApiResponse.notFound(res, 'Không tìm thấy nhà cung cấp');
    }

    // Giao dịch đã bị loại bỏ; trả về transactionCount = 0
    const transactionCount = 0;

    return ApiResponse.success(
      res,
      { supplier: { ...supplier.toObject(), transactionCount } },
      'Lấy thông tin nhà cung cấp thành công'
    );
  } catch (error) {
    console.error('Get supplier by ID error:', error);
    return ApiResponse.error(res, error.message);
  }
};

/**
 * @desc    Cập nhật thông tin nhà cung cấp
 * @route   PUT /api/suppliers/:id
 * @access  Private (Admin, Warehouse Manager)
 */
const updateSupplier = async (req, res) => {
  try {
    const supplier = await Supplier.findById(req.params.id);

    if (!supplier) {
      return ApiResponse.notFound(res, 'Không tìm thấy nhà cung cấp');
    }

    const {
      code,
      name,
      contactPerson,
      phone,
      email,
      address,
      taxCode,
      bankAccount,
      isActive,
    } = req.body;

    // Kiểm tra mã nếu có thay đổi
    if (code && code.toUpperCase() !== supplier.code) {
      const existingSupplier = await Supplier.findOne({
        code: code.toUpperCase(),
      });
      if (existingSupplier) {
        return ApiResponse.badRequest(res, 'Mã nhà cung cấp đã tồn tại');
      }
      supplier.code = code.toUpperCase();
    }

    // Cập nhật các trường
    if (name) supplier.name = name;
    if (contactPerson !== undefined) supplier.contactPerson = contactPerson;
    if (phone) supplier.phone = phone;
    if (email !== undefined) supplier.email = email;
    if (address) supplier.address = address;
    if (taxCode !== undefined) supplier.taxCode = taxCode;
    if (bankAccount) supplier.bankAccount = bankAccount;
    if (isActive !== undefined) supplier.isActive = isActive;

    await supplier.save();
    await supplier.populate('createdBy', 'fullName email');

    return ApiResponse.updated(res, { supplier }, 'Cập nhật nhà cung cấp thành công');
  } catch (error) {
    console.error('Update supplier error:', error);
    return ApiResponse.error(res, error.message);
  }
};

/**
 * @desc    Vô hiệu hóa nhà cung cấp (soft delete)
 * @route   DELETE /api/suppliers/:id
 * @access  Private (Admin, Warehouse Manager)
 */
const deleteSupplier = async (req, res) => {
  try {
    const supplier = await Supplier.findById(req.params.id);
    if (!supplier) {
      return ApiResponse.notFound(res, 'Không tìm thấy nhà cung cấp');
    }

    // Giao dịch đã bị loại bỏ; cho phép vô hiệu hóa ngay lập tức

    supplier.isActive = false;
    await supplier.save();

    return ApiResponse.success(res, null, 'Vô hiệu hóa nhà cung cấp thành công');
  } catch (error) {
    console.error('Delete supplier error:', error);
    return ApiResponse.error(res, error.message);
  }
};

/**
 * @desc    Lấy thống kê giao dịch của nhà cung cấp
 * @route   GET /api/suppliers/:id/statistics
 * @access  Private
 */
const getSupplierStatistics = async (req, res) => {
  try {
    const supplier = await Supplier.findById(req.params.id);

    if (!supplier) {
      return ApiResponse.notFound(res, 'Không tìm thấy nhà cung cấp');
    }

    // Giao dịch đã bị loại bỏ; trả về thống kê mặc định
    const statistics = {
      supplier,
      totalTransactions: 0,
      totalAmount: 0,
      totalProducts: 0,
      recentTransactions: [],
    };

    return ApiResponse.success(res, statistics, 'Lấy thống kê nhà cung cấp thành công');
  } catch (error) {
    console.error('Get supplier statistics error:', error);
    return ApiResponse.error(res, error.message);
  }
};

module.exports = {
  createSupplier,
  getSuppliers,
  getAllSuppliers,
  getSupplierById,
  updateSupplier,
  deleteSupplier,
  getSupplierStatistics,
};

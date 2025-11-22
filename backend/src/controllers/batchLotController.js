const BatchLot = require('../models/BatchLot');
const ApiResponse = require('../utils/response');
const Product = require('../models/Product');
const Supplier = require('../models/Supplier');
const StockIn = require('../models/StockIn');
const mongoose = require('mongoose');

// Lấy giá vốn của lô hàng theo productId và batchNumber
exports.getBatchCost = async (req, res) => {
  try {
    const { product, batchNumber } = req.query;
    if (!product || !batchNumber) {
      return ApiResponse.badRequest(res, 'Thiếu thông tin sản phẩm hoặc số lô');
    }
    if (!mongoose.Types.ObjectId.isValid(product)) {
      return ApiResponse.badRequest(res, 'Product ID không hợp lệ');
    }
    const lot = await BatchLot.findOne({ product, batchNumber });
    if (!lot) {
      return ApiResponse.notFound(res, 'Không tìm thấy lô hàng');
    }
    return ApiResponse.success(res, { costPrice: lot.costPrice });
  } catch (error) {
    try { console.error('Get batch cost error:', error && error.stack ? error.stack : error); } catch (_) {}
    const msg = (process.env.NODE_ENV === 'development' && error && error.message) ? `${error.message}` : 'Có lỗi khi lấy giá vốn lô hàng';
    return ApiResponse.error(res, msg);
  }
};

// Cập nhật một BatchLot (admin/warehouse)
exports.updateBatchLot = async (req, res) => {
  try {
    const { id } = req.params;
    const { remainingQuantity, costPrice, expiryDate, manufacturingDate } = req.body;

    const lot = await BatchLot.findById(id);
    if (!lot) return ApiResponse.notFound(res, 'Không tìm thấy lô hàng');

    if (remainingQuantity != null) {
      if (remainingQuantity < 0) return ApiResponse.badRequest(res, 'remainingQuantity không được âm');
      lot.remainingQuantity = remainingQuantity;
    }
    if (costPrice != null) lot.costPrice = costPrice;
    if (expiryDate != null) lot.expiryDate = new Date(expiryDate);
    if (manufacturingDate != null) lot.manufacturingDate = new Date(manufacturingDate);

    await lot.save();

    // Sau khi cập nhật lô, recompute tổng remainingQuantity cho product và cập nhật product.currentStock
    try {
      const agg = await BatchLot.aggregate([
        { $match: { product: lot.product } },
        { $group: { _id: '$product', totalRemaining: { $sum: '$remainingQuantity' } } }
      ]);
      const total = agg[0] ? agg[0].totalRemaining : 0;
      await Product.updateOne({ _id: lot.product }, { $set: { currentStock: total } });
    } catch (e) {
      console.warn('Warning: failed to recompute product stock after batch update', e && e.message ? e.message : e);
    }

    return ApiResponse.success(res, { batchLot: lot });
  } catch (error) {
    return ApiResponse.error(res, error.message);
  }
};

// Lấy danh sách BatchLots có phân trang và filter
exports.listBatchLots = async (req, res) => {
  try {
    const page = parseInt(req.query.page || '1', 10);
    const limit = Math.min(parseInt(req.query.limit || '50', 10), 200);
    const skip = (Math.max(page, 1) - 1) * limit;

    const match = {};

    // lọc theo productId
    if (req.query.productId) {
      if (mongoose.Types.ObjectId.isValid(req.query.productId)) match.product = new mongoose.Types.ObjectId(req.query.productId);
    }

    // expired flag: expired=true -> expiryDate < now OR status = 'expired'
    if (req.query.expired === 'true') {
      match.$or = [
        { expiryDate: { $lt: new Date() } },
        { status: 'expired' }
      ];
    }

    // nearExpiry flag (in days), default 30 days
    if (req.query.nearExpiry === 'true' || req.query.nearExpiryDays) {
      const days = parseInt(req.query.nearExpiryDays || '30', 10);
      const future = new Date();
      future.setDate(future.getDate() + days);
      match.expiryDate = match.expiryDate || {};
      match.expiryDate.$gte = new Date();
      match.expiryDate.$lte = future;
    }

    // receivedDate range
    if (req.query.receivedFrom || req.query.receivedTo) {
      match.receivedDate = match.receivedDate || {};
      if (req.query.receivedFrom) match.receivedDate.$gte = new Date(req.query.receivedFrom);
      if (req.query.receivedTo) match.receivedDate.$lte = new Date(req.query.receivedTo);
    }

    // search: batchNumber or product name
    const search = req.query.search ? String(req.query.search).trim() : null;

    // Build aggregation
    const pipeline = [
      { $match: match },
      // join product
      {
        $lookup: {
          from: 'products',
          localField: 'product',
          foreignField: '_id',
          as: 'product'
        }
      },
      { $unwind: { path: '$product', preserveNullAndEmptyArrays: true } },
      // join supplier
      {
        $lookup: {
          from: 'suppliers',
          localField: 'supplier',
          foreignField: '_id',
          as: 'supplier'
        }
      },
      { $unwind: { path: '$supplier', preserveNullAndEmptyArrays: true } },
      // join stockIn for code or additional info
      {
        $lookup: {
          from: 'stockins',
          localField: 'stockInRef',
          foreignField: '_id',
          as: 'stockIn'
        }
      },
      { $unwind: { path: '$stockIn', preserveNullAndEmptyArrays: true } },
    ];

    // apply search after lookups
    if (search) {
      const regex = new RegExp(search, 'i');
      pipeline.push({
        $match: {
          $or: [
            { batchNumber: { $regex: regex } },
            { 'product.name': { $regex: regex } },
            { 'stockIn.code': { $regex: regex } }
          ]
        }
      });
    }

    // Sorting: by expiryDate asc, then receivedDate desc
    pipeline.push({ $sort: { expiryDate: 1, receivedDate: -1 } });

    // Facet for pagination
    pipeline.push({
      $facet: {
        items: [ { $skip: skip }, { $limit: limit } ],
        totalCount: [ { $count: 'count' } ]
      }
    });

    let result;
    try {
      result = await BatchLot.aggregate(pipeline).exec();
    } catch (aggErr) {
      try { console.error('Aggregation error in listBatchLots:', aggErr && aggErr.stack ? aggErr.stack : aggErr); } catch (_) {}
      const msg = (process.env.NODE_ENV === 'development' && aggErr && aggErr.message) ? `${aggErr.message}` : 'Có lỗi khi truy vấn lô hàng';
      return ApiResponse.error(res, msg);
    }

    const items = (result && result[0] && Array.isArray(result[0].items)) ? result[0].items : [];
    const total = (result && result[0] && result[0].totalCount && result[0].totalCount[0]) ? result[0].totalCount[0].count : 0;

    // map items to safer shape
    let mapped;
    try {
      mapped = items.map(it => ({
      _id: it._id,
      batchNumber: it.batchNumber,
      product: (() => {
        if (!it.product) return null;
        const p = { _id: it.product._id, name: it.product.name, sku: it.product.sku, minStock: it.product.minStock };
        // include images array so clients can fallback to images if imageUrl not present
        try {
          if (Array.isArray(it.product.images) && it.product.images.length > 0) {
            p.images = it.product.images;
          }
        } catch (e) {
          // ignore
        }
        try {
          if (Array.isArray(it.product.images) && it.product.images.length > 0) {
            const primary = it.product.images.find(img => img && img.isPrimary === true) || it.product.images[0];
            if (primary && primary.url) p.imageUrl = primary.url;
          }
        } catch (e) {
          // ignore
        }
        return p;
      })(),
      supplier: it.supplier ? { _id: it.supplier._id, name: it.supplier.name } : null,
      stockIn: it.stockIn ? { _id: it.stockIn._id, code: it.stockIn.code } : null,
      initialQuantity: it.initialQuantity,
      remainingQuantity: it.remainingQuantity,
      costPrice: it.costPrice,
      manufacturingDate: it.manufacturingDate,
      expiryDate: it.expiryDate,
      receivedDate: it.receivedDate,
      status: it.status,
      notes: it.notes,
      }));
    } catch (mapErr) {
      try { console.error('Mapping error in listBatchLots:', mapErr && mapErr.stack ? mapErr.stack : mapErr, 'itemsSample:', Array.isArray(items) ? items.slice(0,5) : items); } catch (_) {}
      // fallback: return raw items to avoid 500
      return ApiResponse.success(res, {
        items: items || [],
        pagination: { page, limit, total, totalPages: Math.ceil(total / limit) }
      });
    }

    return ApiResponse.success(res, {
      items: mapped,
      pagination: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit)
      }
    });
  } catch (error) {
    try { console.error('Unexpected error in listBatchLots catch:', error && error.stack ? error.stack : error); } catch (_) {}
    const msg = (process.env.NODE_ENV === 'development' && error && error.message) ? `${error.message}` : 'Có lỗi khi lấy danh sách lô hàng';
    return ApiResponse.error(res, msg);
  }
};

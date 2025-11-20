const ActivityLog = require('../models/ActivityLog');
const ApiResponse = require('../utils/response');

/**
 * GET /api/activity-logs
 * Query: page, limit, action, entityType, user, startDate, endDate
 */
const getActivityLogs = async (req, res) => {
  try {
    const {
      page = 1,
      limit = 20,
      action,
      entityType,
      user,
      startDate,
      endDate,
      search,
      sortBy = 'createdAt',
      sortOrder = 'desc',
    } = req.query;

    const query = {};
    if (action) query.action = action;
    if (entityType) query.entityType = entityType;
    if (user) query.user = user;
    if (search) query.$or = [{ description: { $regex: search, $options: 'i' } }];
    if (startDate || endDate) {
      query.createdAt = {};
      if (startDate) query.createdAt.$gte = new Date(startDate);
      if (endDate) query.createdAt.$lte = new Date(endDate);
    }

    const skip = (page - 1) * limit;
    const sort = { [sortBy]: sortOrder === 'desc' ? -1 : 1 };

    const docs = await ActivityLog.find(query)
      .populate('user', 'fullName email')
      .sort(sort)
      .skip(parseInt(skip, 10))
      .limit(parseInt(limit, 10));

    const total = await ActivityLog.countDocuments(query);

    return ApiResponse.paginate(
      res,
      docs,
      { page: parseInt(page, 10), limit: parseInt(limit, 10), total },
      'Lấy lịch sử hoạt động thành công'
    );
  } catch (error) {
    console.error('Get activity logs error:', error);
    return ApiResponse.error(res, error.message);
  }
};

module.exports = {
  getActivityLogs,
};

const multer = require('multer');
const path = require('path');
const ApiResponse = require('../utils/response');

// Cấu hình storage
const storage = multer.memoryStorage();

// File filter - Chỉ cho phép upload ảnh
const fileFilter = (req, file, cb) => {
  // Allowed extensions
  const allowedTypes = /jpeg|jpg|png|gif|webp/;
  
  // Check extension
  const extname = allowedTypes.test(
    path.extname(file.originalname).toLowerCase()
  );
  
  // Check mimetype
  const mimetype = allowedTypes.test(file.mimetype);

  if (mimetype && extname) {
    return cb(null, true);
  } else {
    cb(new Error('Chỉ cho phép upload file ảnh (jpeg, jpg, png, gif, webp)'));
  }
};

// Multer config
const upload = multer({
  storage: storage,
  limits: {
    fileSize: 5 * 1024 * 1024, // 5MB
  },
  fileFilter: fileFilter,
});

// Middleware xử lý lỗi upload
const handleUploadError = (err, req, res, next) => {
  if (err instanceof multer.MulterError) {
    if (err.code === 'LIMIT_FILE_SIZE') {
      return ApiResponse.badRequest(res, 'File quá lớn. Tối đa 5MB');
    }
    if (err.code === 'LIMIT_FILE_COUNT') {
      return ApiResponse.badRequest(res, 'Quá nhiều file');
    }
    return ApiResponse.badRequest(res, err.message);
  } else if (err) {
    return ApiResponse.badRequest(res, err.message);
  }
  next();
};

// Upload single file
const uploadSingle = (fieldName) => {
  return [upload.single(fieldName), handleUploadError];
};

// Upload multiple files
const uploadMultiple = (fieldName, maxCount = 5) => {
  return [upload.array(fieldName, maxCount), handleUploadError];
};

// Upload fields (nhiều field khác nhau)
const uploadFields = (fields) => {
  return [upload.fields(fields), handleUploadError];
};

module.exports = {
  uploadSingle,
  uploadMultiple,
  uploadFields,
};
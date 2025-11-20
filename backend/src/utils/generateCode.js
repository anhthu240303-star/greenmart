/**
 * Hàm tạo mã tự động cho các entity
 */

// Tạo mã với prefix và số thứ tự
const generateCode = (prefix, sequence) => {
  const paddedSequence = String(sequence).padStart(6, '0');
  return `${prefix}${paddedSequence}`;
};


// Tạo mã phiếu nhập
const generateStockInCode = async (Model) => {
  const today = new Date();
  const year = today.getFullYear();
  const month = String(today.getMonth() + 1).padStart(2, '0');
  const prefix = `PN${year}${month}`;
  
  const lastDoc = await Model.findOne({ code: new RegExp(`^${prefix}`) })
    .sort({ createdAt: -1 });
  
  if (!lastDoc) {
    return `${prefix}0001`;
  }
  
  const lastNumber = parseInt(lastDoc.code.replace(prefix, ''));
  const newNumber = String(lastNumber + 1).padStart(4, '0');
  return `${prefix}${newNumber}`;
};

// Tạo mã phiếu xuất
const generateStockOutCode = async (Model) => {
  const today = new Date();
  const year = today.getFullYear();
  const month = String(today.getMonth() + 1).padStart(2, '0');
  const prefix = `PX${year}${month}`;
  
  const lastDoc = await Model.findOne({ code: new RegExp(`^${prefix}`) })
    .sort({ createdAt: -1 });
  
  if (!lastDoc) {
    return `${prefix}0001`;
  }
  
  const lastNumber = parseInt(lastDoc.code.replace(prefix, ''));
  const newNumber = String(lastNumber + 1).padStart(4, '0');
  return `${prefix}${newNumber}`;
};

// Tạo mã kiểm kê
const generateInventoryCheckCode = async (Model) => {
  const today = new Date();
  const year = today.getFullYear();
  const month = String(today.getMonth() + 1).padStart(2, '0');
  const prefix = `KK${year}${month}`;
  
  const lastDoc = await Model.findOne({ code: new RegExp(`^${prefix}`) })
    .sort({ createdAt: -1 });
  
  if (!lastDoc) {
    return `${prefix}0001`;
  }
  
  const lastNumber = parseInt(lastDoc.code.replace(prefix, ''));
  const newNumber = String(lastNumber + 1).padStart(4, '0');
  return `${prefix}${newNumber}`;
};

// Tạo mã giao dịch
const generateTransactionCode = async (Model, type) => {
  const today = new Date();
  const year = today.getFullYear();
  const month = String(today.getMonth() + 1).padStart(2, '0');
  const day = String(today.getDate()).padStart(2, '0');
  
  let prefix = 'TXN';
  if (type === 'in') prefix = 'IN';
  else if (type === 'out') prefix = 'OUT';
  else if (type === 'adjustment') prefix = 'ADJ';
  
  prefix = `${prefix}${year}${month}${day}`;
  
  // If a Model is provided, try to use it to increment sequence
  if (Model && typeof Model.findOne === 'function') {
    try {
      const lastDoc = await Model.findOne({
        transactionCode: new RegExp(`^${prefix}`),
      }).sort({ createdAt: -1 });

      if (lastDoc && lastDoc.transactionCode) {
        const lastNumber = parseInt(lastDoc.transactionCode.replace(prefix, '')) || 0;
        const newNumber = String(lastNumber + 1).padStart(4, '0');
        return `${prefix}${newNumber}`;
      }
    } catch (err) {
      // If Model.findOne fails (e.g., model missing), fall back to safe generation below
      console.warn('generateTransactionCode: could not read Model, falling back to non-sequential code');
    }
  }

  // Fallback: generate a unique-ish code without relying on a Model
  const randomSuffix = String(Math.floor(Math.random() * 9000) + 1000);
  return `${prefix}${randomSuffix}`;
};

// Tạo mã nhà cung cấp
const generateSupplierCode = async (Model) => {
  const prefix = 'SUP';
  
  const lastDoc = await Model.findOne({ code: new RegExp(`^${prefix}`) })
    .sort({ createdAt: -1 });
  
  if (!lastDoc) {
    return `${prefix}01`;
  }
  
  const lastNumber = parseInt(lastDoc.code.replace(prefix, ''));
  const newNumber = String(lastNumber + 1).padStart(2, '0');
  return `${prefix}${newNumber}`;
};

module.exports = {
  generateCode,
  generateStockInCode,
  generateStockOutCode,
  generateInventoryCheckCode,
  generateTransactionCode,
  generateSupplierCode,
};
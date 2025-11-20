/**
 * Backfill ActivityLog documents from existing collections (StockIn, StockOut, Product).
 * Usage:
 *   node scripts/backfill_activity_logs.js --dry --uri="mongodb://..."
 *   node scripts/backfill_activity_logs.js --uri="mongodb://..."
 *
 * Notes:
 * - Always backup your DB before running this script.
 * - Run with --dry first to see what would be created without writing.
 */

const mongoose = require('mongoose');
const path = require('path');

const argUri = process.argv.find(a => a.startsWith('--uri='));
const MONGO_URI = argUri ? argUri.split('=')[1] : (process.env.MONGO_URI || 'mongodb://localhost:27017/greenmart');
const DRY = process.argv.includes('--dry');

async function main() {
  console.log('[backfill] connect to', MONGO_URI);
  await mongoose.connect(MONGO_URI, { useNewUrlParser: true, useUnifiedTopology: true });

  // Require models (adjust paths if your app structure differs)
  const ActivityLog = require(path.join(__dirname, '..', 'src', 'models', 'ActivityLog'));
  const StockIn = require(path.join(__dirname, '..', 'src', 'models', 'StockIn'));
  const StockOut = require(path.join(__dirname, '..', 'src', 'models', 'StockOut'));
  const Product = require(path.join(__dirname, '..', 'src', 'models', 'Product'));

  let created = 0;

  // Friendly Vietnamese labels for common actions
  const actionLabels = {
    create_stock_in: 'Tạo phiếu nhập',
    approve_stock_in: 'Duyệt phiếu nhập',
    cancel_stock_in: 'Hủy phiếu nhập',
    create_stock_out: 'Tạo phiếu xuất',
    approve_stock_out: 'Duyệt phiếu xuất',
    cancel_stock_out: 'Hủy phiếu xuất',
    change_selling_price: 'Thay đổi giá bán',
    create_product: 'Tạo sản phẩm',
    delete_product: 'Xóa sản phẩm',
  };

  async function upsertIfNotExists(doc) {
    // Try to avoid duplicates based on action+entityType+entityId+user+createdAt
    const q = {
      action: doc.action,
      entityType: doc.entityType,
      entityId: doc.entityId,
      user: doc.user,
      createdAt: doc.createdAt,
    };
    const exists = await ActivityLog.findOne(q).lean().exec();
    if (exists) return false;
    if (!DRY) {
      await ActivityLog.create(doc);
    }
    return true;
  }

  console.log('[backfill] scanning StockIn...');
  const stockIns = await StockIn.find().lean().exec();
  for (const s of stockIns) {
    const id = s._id?.toString();
    if (!id) continue;
    if (s.createdBy) {
      const doc = {
        action: 'create_stock_in',
        entityType: 'StockIn',
        entityId: id,
        user: s.createdBy,
        description: `Tạo phiếu nhập #${id}`,
        meta: Object.assign({ total: s.totalAmount ?? s.total }, { actionLabel: actionLabels['create_stock_in'] }),
        createdAt: s.createdAt || s.createdAt || s.updatedAt || new Date(),
      };
      if (await upsertIfNotExists(doc)) created++;
    }
    if (s.approvedBy) {
      const at = s.approvedAt || s.updatedAt || s.createdAt || new Date();
      const doc = {
        action: 'approve_stock_in',
        entityType: 'StockIn',
        entityId: id,
        user: s.approvedBy,
        description: `Duyệt phiếu nhập #${id}`,
        meta: { actionLabel: actionLabels['approve_stock_in'] },
        createdAt: at,
      };
      if (await upsertIfNotExists(doc)) created++;
    }
    if (s.cancelledBy) {
      const at = s.cancelledAt || s.updatedAt || s.createdAt || new Date();
      const doc = {
        action: 'cancel_stock_in',
        entityType: 'StockIn',
        entityId: id,
        user: s.cancelledBy,
        description: `Hủy phiếu nhập #${id}`,
        meta: { actionLabel: actionLabels['cancel_stock_in'] },
        createdAt: at,
      };
      if (await upsertIfNotExists(doc)) created++;
    }
  }

  console.log('[backfill] scanning StockOut...');
  const stockOuts = await StockOut.find().lean().exec();
  for (const s of stockOuts) {
    const id = s._id?.toString();
    if (!id) continue;
    if (s.createdBy) {
      const doc = {
        action: 'create_stock_out',
        entityType: 'StockOut',
        entityId: id,
        user: s.createdBy,
        description: `Tạo phiếu xuất #${id}`,
        meta: Object.assign({ total: s.totalAmount ?? s.total }, { actionLabel: actionLabels['create_stock_out'] }),
        createdAt: s.createdAt || s.updatedAt || new Date(),
      };
      if (await upsertIfNotExists(doc)) created++;
    }
    if (s.approvedBy) {
      const at = s.approvedAt || s.updatedAt || s.createdAt || new Date();
      const doc = {
        action: 'approve_stock_out',
        entityType: 'StockOut',
        entityId: id,
        user: s.approvedBy,
        description: `Duyệt phiếu xuất #${id}`,
        meta: { actionLabel: actionLabels['approve_stock_out'] },
        createdAt: at,
      };
      if (await upsertIfNotExists(doc)) created++;
    }
    if (s.cancelledBy) {
      const at = s.cancelledAt || s.updatedAt || s.createdAt || new Date();
      const doc = {
        action: 'cancel_stock_out',
        entityType: 'StockOut',
        entityId: id,
        user: s.cancelledBy,
        description: `Hủy phiếu xuất #${id}`,
        meta: { actionLabel: actionLabels['cancel_stock_out'] },
        createdAt: at,
      };
      if (await upsertIfNotExists(doc)) created++;
    }
  }

  console.log('[backfill] scanning Products for create events...');
  const products = await Product.find().lean().exec();
  for (const p of products) {
    const id = p._id?.toString();
    if (!id) continue;
    if (p.createdBy) {
      const doc = {
        action: 'create_product',
        entityType: 'Product',
        entityId: id,
        user: p.createdBy,
        description: `Tạo sản phẩm ${p.name || p.title || id}`,
        meta: Object.assign({ sku: p.sku }, { actionLabel: actionLabels['create_product'] }),
        createdAt: p.createdAt || p.updatedAt || new Date(),
      };
      if (await upsertIfNotExists(doc)) created++;
    }
    // delete_product backfill requires deletedBy/deletedAt fields; skip if not present
    if (p.deletedBy || p.deletedAt) {
      const doc = {
        action: 'delete_product',
        entityType: 'Product',
        entityId: id,
        user: p.deletedBy || null,
        description: `Xóa sản phẩm ${p.name || p.title || id}`,
        meta: { actionLabel: actionLabels['delete_product'] },
        createdAt: p.deletedAt || new Date(),
      };
      if (doc.user && await upsertIfNotExists(doc)) created++;
    }
  }

  console.log(`[backfill] finished. Created ${created} ActivityLog documents. ${DRY ? '(dry run)' : ''}`);
  await mongoose.disconnect();
}

main().catch(err => {
  console.error(err);
  process.exit(2);
});

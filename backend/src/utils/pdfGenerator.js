const PDFDocument = require('pdfkit');
const fs = require('fs');
const path = require('path');

/**
 * Helper để tạo PDF chuyên nghiệp cho báo cáo kho siêu thị
 */
class PDFGenerator {
  constructor() {
    this.doc = new PDFDocument({ 
      size: 'A4',
      margin: 40,
      bufferPages: true,
      info: {
        Title: 'GreenMart - Báo cáo quản lý kho',
        Author: 'Hệ thống GreenMart',
        Subject: 'Báo cáo hệ thống quản lý kho'
      }
    });
    this.pageWidth = this.doc.page.width - 80; // margin left + right
    
    // Register fonts that support Vietnamese (try system locations, then warn)
    this.regularFont = 'GM-Regular';
    this.boldFont = 'GM-Bold';
    this.italicFont = 'GM-Italic';

    const candidateFonts = [];
    // Windows
    candidateFonts.push({ regular: 'C:\\Windows\\Fonts\\arial.ttf', bold: 'C:\\Windows\\Fonts\\arialbd.ttf', italic: 'C:\\Windows\\Fonts\\ariali.ttf' });
    // Linux (DejaVu)
    candidateFonts.push({ regular: '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', bold: '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', italic: '/usr/share/fonts/truetype/dejavu/DejaVuSans-Oblique.ttf' });
    // macOS
    candidateFonts.push({ regular: '/Library/Fonts/Arial.ttf', bold: '/Library/Fonts/Arial Bold.ttf', italic: '/Library/Fonts/Arial Italic.ttf' });

    let registered = false;
    for (const cand of candidateFonts) {
      try {
        if (cand.regular && fs.existsSync(cand.regular)) {
          this.doc.registerFont(this.regularFont, cand.regular);
          if (cand.bold && fs.existsSync(cand.bold)) {
            this.doc.registerFont(this.boldFont, cand.bold);
          }
          if (cand.italic && fs.existsSync(cand.italic)) {
            this.doc.registerFont(this.italicFont, cand.italic);
          }
          registered = true;
          break;
        }
      } catch (err) {
        // continue to next candidate
      }
    }

    if (!registered) {
      // Try to load from project folder backend/fonts if available
      const localReg = path.join(__dirname, '..', 'fonts', 'DejaVuSans.ttf');
      const localBold = path.join(__dirname, '..', 'fonts', 'DejaVuSans-Bold.ttf');
      const localItalic = path.join(__dirname, '..', 'fonts', 'DejaVuSans-Oblique.ttf');
      try {
        if (fs.existsSync(localReg)) {
          this.doc.registerFont(this.regularFont, localReg);
          if (fs.existsSync(localBold)) this.doc.registerFont(this.boldFont, localBold);
          if (fs.existsSync(localItalic)) this.doc.registerFont(this.italicFont, localItalic);
          registered = true;
        }
      } catch (err) {}
    }

    if (!registered) {
      console.warn('[PDFGenerator] Không tìm thấy font hệ thống hỗ trợ Tiếng Việt. Vui lòng cài Arial/DejaVu hoặc đặt ttf vào `backend/fonts/` để đảm bảo hiển thị tiếng Việt chính xác. Sẽ sử dụng font mặc định (có thể không hiển thị dấu).');
      // fallback to built-in fonts names (these don't support Vietnamese diacritics reliably)
      this.regularFont = 'Helvetica';
      this.boldFont = 'Helvetica-Bold';
      this.italicFont = 'Helvetica-Oblique';
    }
  }

  // Thêm header công ty
  addCompanyHeader(companyName, address, phone, taxCode = '') {
    const topMargin = 30;
    
    // Logo placeholder
    this.doc
      .rect(40, topMargin, 60, 60)
      .fillAndStroke('#4CAF50', '#2E7D32');
    
    this.doc
      .fontSize(10)
      .fillColor('white')
      .text('GM', 55, topMargin + 22, { width: 30, align: 'center' });

    // Company info
    this.doc
      .fillColor('#1a1a1a')
      .fontSize(14)
      .font(this.boldFont)
      .text(companyName, 110, topMargin, { width: 400 });
    
    this.doc
      .fontSize(8)
      .font(this.regularFont)
      .fillColor('#555')
      .text(address, 110, topMargin + 18)
      .text(`Điện thoại: ${phone} ${taxCode ? `| Mã số thuế: ${taxCode}` : ''}`, 110, topMargin + 30);

    // Divider
    this.doc
      .moveTo(40, topMargin + 70)
      .lineTo(this.doc.page.width - 40, topMargin + 70)
      .strokeColor('#4CAF50')
      .lineWidth(2)
      .stroke();

    this.doc.y = topMargin + 85;
    return this;
  }

  // Tiêu đề báo cáo
  addReportTitle(title, subtitle = '', reportType = 'INFO') {
    const y = this.doc.y;
    
    const badgeColors = {
      'INVENTORY': '#2196F3',
      'STOCK_IN': '#4CAF50', 
      'STOCK_OUT': '#FF9800',
      'SUMMARY': '#9C27B0',
      'INFO': '#607D8B'
    };
    
    const badgeColor = badgeColors[reportType] || badgeColors.INFO;
    
    // Badge loại báo cáo
    this.doc
      .roundedRect(40, y, 100, 20, 3)
      .fillAndStroke(badgeColor, badgeColor);
    
    this.doc
      .fontSize(9)
      .fillColor('white')
      .font(this.boldFont)
      .text(reportType.replace('_', ' '), 40, y + 6, { width: 100, align: 'center' });

    // Main title
    this.doc
      .fontSize(18)
      .fillColor('#1a1a1a')
      .font(this.boldFont)
      .text(title, 150, y, { width: this.pageWidth - 110 });

    if (subtitle) {
      this.doc
        .fontSize(11)
        .fillColor('#666')
        .font(this.regularFont)
        .text(subtitle, 150, y + 22, { width: this.pageWidth - 110 });
    }

    this.doc.moveDown(2.5);
    return this;
  }

  // Meta báo cáo
  addReportMeta(date = new Date(), createdBy = '', reportCode = '') {
    const y = this.doc.y;
    const boxHeight = 60;
    
    // Box background
    this.doc
      .roundedRect(40, y, this.pageWidth, boxHeight, 5)
      .fillAndStroke('#f5f5f5', '#e0e0e0');

    const iconSize = 12;
    const leftCol = 55;
    const rightCol = this.pageWidth / 2 + 40;

    // Ngày tạo
    this.doc
      .circle(leftCol, y + 18, iconSize / 2)
      .fillAndStroke('#4CAF50', '#4CAF50');
    
    this.doc
      .fontSize(8)
      .fillColor('#666')
      .font(this.regularFont)
      .text('Ngày tạo báo cáo', leftCol + 15, y + 13);
    
    const dateStr = date.toLocaleString('vi-VN', {
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit'
    });
    
    this.doc
      .fontSize(10)
      .fillColor('#1a1a1a')
      .font(this.boldFont)
      .text(dateStr, leftCol + 15, y + 26);

    // Người tạo
    if (createdBy) {
      this.doc
        .circle(rightCol, y + 18, iconSize / 2)
        .fillAndStroke('#2196F3', '#2196F3');
      
      this.doc
        .fontSize(8)
        .fillColor('#666')
        .font(this.regularFont)
        .text('Nguời tạo', rightCol + 15, y + 13);
      
      this.doc
        .fontSize(10)
        .fillColor('#1a1a1a')
        .font(this.boldFont)
        .text(createdBy, rightCol + 15, y + 26);
    }

    // Mã báo cáo
    if (reportCode) {
      this.doc
        .fontSize(8)
        .fillColor('#666')
        .font(this.regularFont)
        .text(`Mã báo cáo: ${reportCode}`, leftCol + 15, y + 45);
    }

    this.doc.y = y + boxHeight + 20;
    return this;
  }

  // Vẽ bảng
  drawTable(headers, rows, columnWidths, options = {}) {
    const {
      headerBgColor = '#4CAF50',
      headerTextColor = '#ffffff',
      rowAltColor = '#f9f9f9',
      rowBorderColor = '#e0e0e0',
      alignments = []
    } = options;

    const startX = 40;
    let startY = this.doc.y;
    const rowHeight = 28;
    const headerHeight = 35;

    // Header
    this.doc
      .roundedRect(startX, startY, this.pageWidth, headerHeight, 3)
      .fillAndStroke(headerBgColor, headerBgColor);

    this.doc.fontSize(9).fillColor(headerTextColor).font(this.boldFont);

    let currentX = startX;
    headers.forEach((header, i) => {
      const align = alignments[i] || (i === 0 ? 'left' : 'center');
      this.doc.text(header, currentX + 8, startY + 11, {
        width: columnWidths[i] - 16,
        align
      });
      currentX += columnWidths[i];
    });

    startY += headerHeight;
    this.doc.font(this.regularFont).fontSize(9);

    // Rows
    rows.forEach((row, rowIndex) => {
      // New page check
      if (startY + rowHeight > this.doc.page.height - 60) {
        this.doc.addPage();
        startY = 50;

        // Redraw header
        this.doc
          .roundedRect(startX, startY, this.pageWidth, headerHeight, 3)
          .fillAndStroke(headerBgColor, headerBgColor);

        this.doc.fontSize(9).fillColor(headerTextColor).font(this.boldFont);
        currentX = startX;
        headers.forEach((header, i) => {
          const align = alignments[i] || (i === 0 ? 'left' : 'center');
          this.doc.text(header, currentX + 8, startY + 11, {
            width: columnWidths[i] - 16,
            align
          });
          currentX += columnWidths[i];
        });

        startY += headerHeight;
        this.doc.font(this.regularFont).fontSize(9);
      }

      // Row background
      if (rowIndex % 2 === 0) {
        this.doc
          .rect(startX, startY, this.pageWidth, rowHeight)
          .fillAndStroke(rowAltColor, rowBorderColor);
      } else {
        this.doc
          .rect(startX, startY, this.pageWidth, rowHeight)
          .stroke(rowBorderColor);
      }

      // Row cells
      currentX = startX;
      row.forEach((cell, i) => {
        const align = alignments[i] || (i === 0 ? 'left' : 'right');
        const textColor = i === row.length - 1 ? '#1a1a1a' : '#333';
        const fontToUse = i === row.length - 1 ? this.boldFont : this.regularFont;

        this.doc
          .fillColor(textColor)
          .font(fontToUse)
          .text(String(cell ?? '-'), currentX + 8, startY + 9, {
            width: columnWidths[i] - 16,
            align
          });
        currentX += columnWidths[i];
      });

      startY += rowHeight;
    });

    this.doc.y = startY + 15;
    return this;
  }

  // Summary cards
  addSummaryCards(items, options = {}) {
    const { columns = 3 } = options;
    const cardWidth = (this.pageWidth - (columns - 1) * 15) / columns;
    const cardHeight = 65;
    const startY = this.doc.y;
    
    items.forEach((item, index) => {
      const row = Math.floor(index / columns);
      const col = index % columns;
      const x = 40 + col * (cardWidth + 15);
      const y = startY + row * (cardHeight + 15);

      this.doc
        .roundedRect(x, y, cardWidth, cardHeight, 5)
        .fillAndStroke('#ffffff', '#e0e0e0');

      this.doc
        .roundedRect(x, y, cardWidth, 5, 5)
        .fillAndStroke(item.color || '#4CAF50', item.color || '#4CAF50');

      this.doc
        .circle(x + 20, y + 30, 15)
        .fillAndStroke((item.color || '#4CAF50') + '20', (item.color || '#4CAF50') + '20');

      this.doc
        .fontSize(8)
        .fillColor('#666')
        .font(this.regularFont)
        .text(item.label, x + 45, y + 15, { width: cardWidth - 55 });

      this.doc
        .fontSize(16)
        .fillColor('#1a1a1a')
        .font(this.boldFont)
        .text(item.value, x + 45, y + 30, { width: cardWidth - 55 });

      if (item.subtitle) {
        this.doc
          .fontSize(7)
          .fillColor('#999')
          .font(this.regularFont)
          .text(item.subtitle, x + 45, y + 50, { width: cardWidth - 55 });
      }
    });

    const totalRows = Math.ceil(items.length / columns);
    this.doc.y = startY + totalRows * (cardHeight + 15) + 10;
    return this;
  }

  // Section header
  addSectionHeader(title) {
    const y = this.doc.y;

    this.doc
      .rect(40, y, 5, 20)
      .fillAndStroke('#4CAF50', '#4CAF50');

    this.doc
      .fontSize(13)
      .fillColor('#1a1a1a')
      .font(this.boldFont)
      .text(title, 55, y + 3);

    this.doc.moveDown(1.5);
    return this;
  }

  // Watermark
  addWatermark(text = 'GREENMART') {
    // Watermark removed by request — keep method to preserve API but do nothing.
    return this;
  }

  // Footer
  addFooter(includeSignature = false) {
    const pages = this.doc.bufferedPageRange();
    for (let i = 0; i < pages.count; i++) {
      this.doc.switchToPage(i);
      const bottomY = this.doc.page.height - 50;

      this.doc
        .moveTo(40, bottomY)
        .lineTo(this.doc.page.width - 40, bottomY)
        .strokeColor('#e0e0e0')
        .lineWidth(1)
        .stroke();

      this.doc
        .fontSize(8)
        .fillColor('#999')
        .font(this.regularFont)
        .text(`Trang ${i + 1} / ${pages.count}`, 40, bottomY + 8, {
          align: 'center',
          width: this.doc.page.width - 80
        });

      this.doc
        .fontSize(7)
        .font(this.regularFont)
        .text(`© ${new Date().getFullYear()} GreenMart - Hệ thống quản lý kho chuyên nghiệp`,
          40, bottomY + 22,
          { align: 'center', width: this.doc.page.width - 80 }
        );

      // Signature chỉ ở trang cuối
      if (includeSignature && i === pages.count - 1) {
        const sigY = bottomY - 80;
        const colWidth = (this.doc.page.width - 80) / 3;
        
        const signatures = [
          { title: 'Người lập', name: '(Ký, ghi rõ họ tên)' },
          { title: 'Thủ kho', name: '(Ký, ghi rõ họ tên)' },
          { title: 'Giám đốc', name: '(Ký, ghi rõ họ tên)' }
        ];

          signatures.forEach((sig, idx) => {
          const x = 40 + idx * colWidth;
          this.doc
            .fontSize(9)
            .fillColor('#333')
            .font(this.boldFont)
            .text(sig.title, x, sigY, { width: colWidth, align: 'center' });
          
          this.doc
            .fontSize(7)
            .fillColor('#999')
            .font(this.italicFont)
            .text(sig.name, x, sigY + 15, { width: colWidth, align: 'center' });
        });
      }
    }
    return this;
  }

  // Save
  save(filePath) {
    return new Promise((resolve, reject) => {
      const stream = fs.createWriteStream(filePath);
      // Try to trim any accidental empty trailing page before finalizing
      try {
        this._removeEmptyTrailingPage();
      } catch (err) {
        // don't block saving on trim errors
      }

      this.doc.pipe(stream);
      this.doc.end();
      
      stream.on('finish', () => resolve(filePath));
      stream.on('error', reject);
    });
  }

  // Pipe trực tiếp ra response
  pipe(res) {
    // ensure trailing empty pages trimmed before piping
    try {
      this._removeEmptyTrailingPage();
    } catch (err) {}

    this.doc.pipe(res);
    return this;
  }

  end() {
    this.doc.end();
    return this;
  }

  // Best-effort: remove trailing empty page if the last page has almost no content
  _removeEmptyTrailingPage() {
    try {
      const pagesRef = this.doc._root && this.doc._root.data && this.doc._root.data.Pages;
      if (!pagesRef || !pagesRef.data) return;

      const kids = pagesRef.data.Kids;
      if (!Array.isArray(kids) || kids.length < 2) return; // keep at least one page

      const lastRef = kids[kids.length - 1];
      const lastPage = lastRef && lastRef.data;
      if (!lastPage) return;

      // If the page has no Contents or very small Contents array, consider it empty.
      const contents = lastPage.Contents;

      // Helper to estimate stream size (best-effort across pdfkit internal shapes)
      const estimateStreamSize = (streamRef) => {
        try {
          if (!streamRef) return 0;
          const data = streamRef.data || streamRef._data || streamRef;
          if (!data) return 0;
          if (Buffer.isBuffer(data)) return data.length;
          if (typeof data === 'string') return data.length;
          if (Array.isArray(data)) {
            return data.reduce((s, it) => {
              if (!it) return s;
              if (Buffer.isBuffer(it)) return s + it.length;
              if (typeof it === 'string') return s + it.length;
              if (it.length) return s + it.length;
              return s;
            }, 0);
          }
          if (data.chunks && Array.isArray(data.chunks)) {
            return data.chunks.reduce((s, c) => s + (c ? (c.length || 0) : 0), 0);
          }
          if (data._chunks && Array.isArray(data._chunks)) {
            return data._chunks.reduce((s, c) => s + (c ? (c.length || 0) : 0), 0);
          }
          if (typeof data.length === 'number') return data.length;
        } catch (e) {}
        return 0;
      };

      let totalSize = 0;
      if (!contents) {
        totalSize = 0;
      } else if (Array.isArray(contents)) {
        totalSize = contents.reduce((s, c) => s + estimateStreamSize(c), 0);
      } else {
        totalSize = estimateStreamSize(contents);
      }

      // If total stream size is very small (heuristic threshold), remove page.
      // Threshold tuned to treat pages that only contain footer/watermark as empty: 300 bytes
      if (totalSize < 300) {
        kids.pop();
        pagesRef.data.Count = kids.length;
        if (Array.isArray(this.doc._pageBuffer)) {
          this.doc._pageBuffer.pop();
        }
        if (Array.isArray(this.doc._pages)) {
          this.doc._pages.pop();
        }
        // console.info('[PDFGenerator] Removed trailing nearly-empty page (size=' + totalSize + ')');
      }
    } catch (err) {
      // ignore internals errors
    }
  }
}

module.exports = PDFGenerator;


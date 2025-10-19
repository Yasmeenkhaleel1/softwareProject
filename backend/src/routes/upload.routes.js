// src/routes/upload.routes.js
import express from 'express';
import multer from 'multer';
import path from 'path';
import fs from 'fs';
import { fileURLToPath } from 'url';

const router = express.Router();

// تحديد المسار الحالي
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// ====== 🔹 إنشاء المجلدات تلقائيًا إذا غير موجودة ======
const createFolderIfMissing = (folderPath) => {
  if (!fs.existsSync(folderPath)) {
    fs.mkdirSync(folderPath, { recursive: true });
    console.log('📁 Created folder:', folderPath);
  }
};

const certPath = path.join(process.cwd(), 'src', 'uploads', 'certificates');
const galleryPath = path.join(process.cwd(), 'src', 'uploads', 'gallery');
const profilePath = path.join(process.cwd(), 'src', 'uploads', 'profile_pictures');

createFolderIfMissing(profilePath);
createFolderIfMissing(certPath);
createFolderIfMissing(galleryPath);

// ====== إعداد الـ Storage (يُستخدم في الاثنين) ======
const createStorage = (uploadDir) =>
  multer.diskStorage({
    destination: (req, file, cb) => {
      cb(null, uploadDir);
    },
    filename: (req, file, cb) => {
      const unique = Date.now() + '-' + Math.round(Math.random() * 1e9);
      const ext = path.extname(file.originalname);
      cb(null, unique + ext);
    },
  });

// ====== فلترة أنواع الملفات المسموحة ======
const allowed = new Set(['.pdf', '.png', '.jpg', '.jpeg']);
const fileFilter = (req, file, cb) => {
  const ext = path.extname(file.originalname).toLowerCase();
  if (allowed.has(ext)) cb(null, true);
  else cb(new Error('Invalid file type. Allowed: pdf, png, jpg, jpeg'));
};

// إعداد Multer للشهادات
const uploadCertificates = multer({
  storage: createStorage(certPath),
  fileFilter,
  limits: { fileSize: 5 * 1024 * 1024 },
});

// إعداد Multer للمعرض
const uploadGallery = multer({
  storage: createStorage(galleryPath),
  fileFilter,
  limits: { fileSize: 10 * 1024 * 1024 },
});

// Storage لملف البروفايل (صورة واحدة)
const uploadProfile = multer({
  storage: createStorage(profilePath),
  fileFilter,                         // نفس فلتر الامتدادات: .png/.jpg/.jpeg
  limits: { fileSize: 5 * 1024 * 1024 }, // 5MB
});

// ====== 📄 رفع الشهادات ======
router.post('/upload/certificates', uploadCertificates.array('certificates', 5), (req, res) => {
  try {
    const base = `${req.protocol}://${req.get('host')}`;
    const files = (req.files || []).map(f => ({
      filename: f.filename,
      url: `${base}/uploads/certificates/${f.filename}`,
      size: f.size,
      mimetype: f.mimetype,
    }));
    return res.status(201).json({ message: 'Certificates uploaded successfully', files });
  } catch (err) {
    console.error('❌ Upload certificates error:', err);
    return res.status(500).json({ message: 'Upload failed', error: err.message });
  }
});

// ====== 🖼️ رفع صور المعرض ======
router.post('/upload/gallery', uploadGallery.array('gallery', 10), (req, res) => {
  try {
    const base = `${req.protocol}://${req.get('host')}`;
    const files = (req.files || []).map(f => ({
      filename: f.filename,
      url: `${base}/uploads/gallery/${f.filename}`,
      size: f.size,
      mimetype: f.mimetype,
    }));
    return res.status(201).json({ message: 'Gallery images uploaded successfully', files });
  } catch (err) {
    console.error('❌ Upload gallery error:', err);
    return res.status(500).json({ message: 'Upload failed', error: err.message });
  }
});

// ====== 👤 رفع صورة البروفايل (ملف واحد) ======
router.post('/upload/profile', uploadProfile.single('avatar'), (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ message: 'No file uploaded' });
    }
    const base = `${req.protocol}://${req.get('host')}`;
    const file = req.file;
    return res.status(201).json({
      message: 'Profile image uploaded successfully',
      file: {
        filename: file.filename,
        url: `${base}/uploads/profile_pictures/${file.filename}`,
        size: file.size,
        mimetype: file.mimetype,
      },
    });
  } catch (err) {
    console.error('❌ Upload profile error:', err);
    return res.status(500).json({ message: 'Upload failed', error: err.message });
  }
});

// ====== 👤 رفع صورة بروفايل الزبون (Customer Profile) ======
const customerPath = path.join(process.cwd(), 'src', 'uploads', 'customer_pictures');
createFolderIfMissing(customerPath);

const uploadCustomer = multer({
  storage: createStorage(customerPath),
  fileFilter,
  limits: { fileSize: 5 * 1024 * 1024 }, // 5MB
});

router.post('/upload/customer', uploadCustomer.single('file'), (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ message: 'No file uploaded' });
    }
    const base = `${req.protocol}://${req.get('host')}`;
    const file = req.file;
    return res.status(201).json({
      message: 'Customer profile image uploaded successfully',
      file: {
        filename: file.filename,
        url: `${base}/uploads/customer_pictures/${file.filename}`,
        size: file.size,
        mimetype: file.mimetype,
      },
    });
  } catch (err) {
    console.error('❌ Upload customer profile error:', err);
    return res.status(500).json({ message: 'Upload failed', error: err.message });
  }
});


export default router;

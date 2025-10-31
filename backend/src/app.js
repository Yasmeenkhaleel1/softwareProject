// src/app.js
import cors from 'cors';
import mongoose from 'mongoose';
import express from 'express';
import path from 'path';
import dotenv from 'dotenv';           // ✅ جديد
import { fileURLToPath } from 'url';

// Routers
import userRouter from './routes/user.routes.js';
import expertProfileRouter from './routes/expertProfile.routes.js';
import uploadRouter from './routes/upload.routes.js';
import authRouter from './routes/auth.routes.js';    // ✅ جديد
import customerRoutes from "./routes/customer.routes.js";

import adminRoutes from "./routes/admin.route.js";
import notificationRoutes from "./routes/notification.route.js";

import serviceRouter from "./routes/service.route.js";
// تحديد المسار الحالي (لخدمة ملفات الرفع)

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// تحميل إعدادات .env من الجذر
dotenv.config(); // ✅ ضروري جدًا لتقرأ القيم مثل MONGO_URI و SMTP...

const initAPP = (app) => {
  app.use(express.json());
  app.use(cors());

  // ✅ خدمة الملفات المرفوعة (صور - شهادات)
  app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

  // ✅ الاتصال بقاعدة البيانات (من env بدل كتابة الرابط داخل الكود)
  mongoose.connect(process.env.MONGO_URI, {
    useNewUrlParser: true,
    useUnifiedTopology: true,
  })
  .then(() => console.log('✅ MongoDB connected successfully'))
  .catch(err => console.log('❌ DB connection error:', err.message));

  // ✅ تعريف المسارات (Routes)
  app.use('/api', userRouter);
  app.use('/api/expertProfiles', expertProfileRouter);

  app.use('/api', uploadRouter);
  
  app.use('/auth', authRouter);  // ✅ مهم: إضافة مسار auth

app.use("/api", customerRoutes);

app.use('/api/admin', adminRoutes);
app.use('/api/notifications', notificationRoutes);
  console.log('✅ App initialized successfully');
app.use("/api/services", serviceRouter);
};

export default initAPP;

// src/app.js
import cors from "cors";
import mongoose from "mongoose";
import express from "express";
import path from "path";
import dotenv from 'dotenv';
import { fileURLToPath } from "url";

// Routers
import webhookRoute from "./routes/webhook.route.js";
import disputeRoutes from "./routes/dispute.routes.js";
import userRouter from "./routes/user.routes.js";
import expertProfileRouter from "./routes/expertProfile.routes.js";
import uploadRouter from "./routes/upload.routes.js";
import authRouter from "./routes/auth.routes.js";
import customerRoutes from "./routes/customer.routes.js";
import adminRoutes from "./routes/admin.route.js";
import notificationRoutes from "./routes/notification.route.js";
import serviceRouter from "./routes/service.route.js";
import expertBookingRoute from "./routes/expert.booking.route.js";

// ✅ Routes الجديدة الخاصة بالكستمر والدفع والحجوزات العامة
import bookingPublicRoutes from "./routes/booking.routes.js";       // 🧾 الكستمر – إنشاء حجوزات عامة
import availabilityRoutes from "./routes/availability.routes.js";   // 📅 التوافر (Available Slots)
import expertAvailabilityRoutes from "./routes/expert.availability.routes.js";
import calendarRouter from "./routes/calendar.route.js";
import paymentRoutes from "./routes/payments.routes.js";            // 💳 الدفع العام
import expertEarningsRoutes from "./routes/expertEarnings.route.js";


import notifyRoutes from "./routes/notify.route.js";
import fcmRoutes from "./routes/fcm.route.js";

import publicServicesRoutes from "./routes/public.services.routes.js";

import messageRoutes from "./routes/message.route.js";

import aiRoutes from "./routes/ai.route.js";
// إعدادات المسار العام
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
// تحميل إعدادات البيئة
dotenv.config();

const initAPP = (app) => {
  
  app.use("/stripe", webhookRoute);
  app.use(express.json());
  app.use(cors());

  // ✅ الملفات المرفوعة (صور وشهادات)
  app.use("/uploads", express.static(path.join(__dirname, "uploads")));

  // ✅ الاتصال بقاعدة البيانات
  mongoose
    .connect(process.env.MONGO_URI, {
      useNewUrlParser: true,
      useUnifiedTopology: true,
    })
    .then(() => console.log("✅ MongoDB connected successfully"))
    .catch((err) =>
      console.log("❌ DB connection error:", err.message)
    );

  // ==========================
  // ✅ تعريف جميع الـ Routes
  // ==========================


// 🔹 المستخدمين (User)
app.use("/api", userRouter);

// 🔹 بروفايلات الخبراء (Expert Profiles)
app.use("/api/expertProfiles", expertProfileRouter);

// 🔹 رفع الملفات (Uploads)
app.use("/api", uploadRouter);

// 🔹 المصادقة (Auth)
app.use("/auth", authRouter);

// 🔹 العملاء (Customers)
app.use("/api", customerRoutes);

// 🔹 الخدمات (Services)
app.use("/api/services", serviceRouter);

app.use("/api", publicServicesRoutes);//serch


// 🔹 الحجوزات العامة (Public Booking) ← يجب أن تبقى قبل expertBookingRoute
app.use("/api", bookingPublicRoutes);

// 🔹 التوافر (Availability)
app.use("/api", availabilityRoutes);

// 🔹 التقويم (Calendar Status) 
app.use("/api", calendarRouter);


// 🔹 Expert Availability (Private)
app.use("/api", expertAvailabilityRoutes);

// 🔹 الدفع (Payments)
app.use("/api/payments", paymentRoutes);

app.use("/api/expert/earnings", expertEarningsRoutes);

// 🔹 النظام الجديد (Disputes / شكاوي الدفع)
app.use("/api", disputeRoutes);


app.use("/api/fcm", fcmRoutes);

// 🔹 الإشعارات (Notifications)
app.use("/api/notifications", notificationRoutes);

app.use("/api/notify", notifyRoutes);

app.use("/api/messages", messageRoutes);


app.use("/api/assistant", aiRoutes);
// 🔹 الإدارة (Admin)
app.use("/api/admin", adminRoutes);

// 🔹 حجوزات الخبير (Expert Dashboard) ← آخر شيء دائمًا
app.use("/api", expertBookingRoute);


  console.log("✅ App initialized successfully");
};

export default initAPP;

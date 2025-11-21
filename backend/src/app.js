// src/app.js
import cors from "cors";
import mongoose from "mongoose";
import express from "express";
import path from "path";
import dotenv from "dotenv";
import { fileURLToPath } from "url";

// Routers
import chatbotRoutes from "./routes/chatbot.routes.js";
import userRouter from "./routes/user.routes.js";
import expertProfileRouter from "./routes/expertProfile.routes.js";
import uploadRouter from "./routes/upload.routes.js";
import authRouter from "./routes/auth.routes.js"; // لو ما عندك هالملف احذفي هالسطر
import customerRoutes from "./routes/customer.routes.js";

import adminRoutes from "./routes/admin.route.js";
import notificationRoutes from "./routes/notification.route.js";

import serviceRouter from "./routes/service.route.js";
import expertBookingRoute from "./routes/expert.booking.route.js";
import availabilityRoutes from "./routes/availability.routes.js";
import bookingsRoutes from "./routes/bookings.routes.js";
import paymentsRoutes from "./routes/payments.routes.js";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// تحميل إعدادات .env من الجذر
dotenv.config(); // مهم عشان تقرأ MONGO_URI و غيرها

const initAPP = (app) => {
  app.use(express.json());
  app.use(cors({ origin: true, credentials: true }));

  // ملفات الرفع
  app.use("/uploads", express.static(path.join(__dirname, "uploads")));

  // الاتصال بقاعدة البيانات
  mongoose
    .connect(process.env.MONGO_URI, {
      useNewUrlParser: true,
      useUnifiedTopology: true,
    })
    .then(() => console.log("✅ MongoDB connected successfully"))
    .catch((err) => console.log("❌ DB connection error:", err.message));

  // المسارات (Routes)
  app.use("/api", userRouter);
  app.use("/api/expertProfiles", expertProfileRouter);
  app.use("/api", uploadRouter);

  // auth (لو عندك تسجيل/تسجيل دخول)
  app.use("/auth", authRouter);

  app.use("/api", customerRoutes);
  app.use("/api/admin", adminRoutes);
  app.use("/api/notifications", notificationRoutes);

  app.use("/api/services", serviceRouter);
  app.use("/api", expertBookingRoute);
  app.use("/api", availabilityRoutes);

  // الحجز و الدفع (public)
  app.use("/api", bookingsRoutes);
  app.use("/api", paymentsRoutes);
  app.use("/api", chatbotRoutes);
  console.log("✅ App initialized successfully");
};

export default initAPP;

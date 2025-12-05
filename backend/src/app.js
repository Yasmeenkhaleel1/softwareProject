import cors from "cors";
import mongoose from "mongoose";
import express from "express";
import path from "path";
import dotenv from "dotenv";
import { fileURLToPath } from "url";

// Chatbot Route
import chatbotRoutes from "./routes/chatbot.routes.js";

// Other Routes...
import userRouter from "./routes/user.routes.js";
import expertProfileRouter from "./routes/expertProfile.routes.js";
import uploadRouter from "./routes/upload.routes.js";
import authRouter from "./routes/auth.routes.js";
import customerRoutes from "./routes/customer.routes.js";
import adminRoutes from "./routes/admin.route.js";
import notificationRoutes from "./routes/notification.route.js";
import serviceRouter from "./routes/service.route.js";
import expertBookingRoute from "./routes/expert.booking.route.js";
import bookingPublicRoutes from "./routes/booking.routes.js";
import availabilityRoutes from "./routes/availability.routes.js";
import expertAvailabilityRoutes from "./routes/expert.availability.routes.js";
import calendarRouter from "./routes/calendar.route.js";
import paymentRoutes from "./routes/payments.routes.js";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

dotenv.config();

const initAPP = (app) => {


  // ===========================
  // GLOBAL MIDDLEWARES
  // ===========================
  app.use(express.json());
app.use(
  cors({
    origin: "*",
    methods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allowedHeaders: ["Content-Type", "Authorization"],
  })
);



  // Static uploads
  app.use("/uploads", express.static(path.join(__dirname, "uploads")));

  // ===========================
  // 🔥 CHATBOT ROUTE (MUST COME FIRST)
  // ===========================
app.use("/api/chatbot", chatbotRoutes);

  // ===========================
  // DATABASE
  // ===========================
  mongoose.connect(process.env.MONGO_URI)
    .then(() => console.log("✅ MongoDB connected successfully"))
    .catch(err => console.log("❌ DB error:", err.message));

  // ===========================
  // API ROUTES
  // ===========================
  app.use("/api", userRouter);
  app.use("/api/expertProfiles", expertProfileRouter);
  app.use("/api", uploadRouter);
  app.use("/auth", authRouter);
  app.use("/api", customerRoutes);
  app.use("/api/services", serviceRouter);
  app.use("/api", bookingPublicRoutes);
  app.use("/api", availabilityRoutes);
  app.use("/api", calendarRouter);
  app.use("/api", expertAvailabilityRoutes);
  app.use("/api", paymentRoutes);
  app.use("/api/notifications", notificationRoutes);
  app.use("/api/admin", adminRoutes);
  app.use("/api", expertBookingRoute);

  console.log("✅ App initialized successfully");
};

export default initAPP;

import express from "express";
import cors from "cors";
import connectDB from "./config/db.js";
import userRoutes from "./routes/user.routes.js";
import authRoutes from "./routes/auth.route.js";
import dotenv from 'dotenv';
dotenv.config({ path: './src/.env' });
const app = express();
const PORT = 5000;

app.use(cors());
app.use(express.json());

// Connect to DB
connectDB();

// Routes
app.use("/api", userRoutes);
app.use("/api", authRoutes);

app.listen(PORT, () => console.log(`🚀 Server running on port ${PORT}`));

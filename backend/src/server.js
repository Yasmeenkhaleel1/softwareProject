import express from "express";
import cors from "cors";
import dotenv from "dotenv";
import connectDB from "./config/db.js";
import userRoutes from "./routes/user.routes.js";
import authRoutes from "./routes/auth.route.js";

dotenv.config(); 

const app = express();
const PORT = process.env.PORT || 5000;

app.use(cors());
app.use(express.json());

connectDB();

// Routes
app.use("/api", userRoutes);
app.use("/api", authRoutes);

app.listen(PORT, () => console.log(`🚀 Server running on port ${PORT}`));

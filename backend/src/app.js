import express from "express";
import connectDB from "./config/connection.js";    
import userRouter from "./routes/user.routes.js";

const initAPP = async (app) => {
  await connectDB();
  app.use(express.json());
  app.use("/users", userRouter);
  app.get("/", (req, res) => res.send("✅ Lost Treasures Backend Running"));
};

export default initAPP;

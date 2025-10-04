import express from "express";
import connectDB from "../connection.js";    
import authRouter from "../routers/user.router.js";

const initAPP = async (app) => {
 
  await connectDB(); 


  app.use(express.json());

  app.use("/users", authRouter);

  app.get("/", (req, res) => {
    res.send("Hello from initAPP ✅");
  });
};

export default initAPP;

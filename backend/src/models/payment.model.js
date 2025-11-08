// src/models/payment.model.js
import mongoose from "mongoose";

const PaymentSchema = new mongoose.Schema(
  {
    holderName: String,
    cardLast4: String,
    brand: String,   // VISA / MASTERCARD / ...
    expiry: String,  // e.g. "03/30"
    amount: Number,
    currency: { type: String, default: "USD" },
    status: {
      type: String,
      enum: ["PENDING", "CAPTURED", "FAILED"],
      default: "CAPTURED",
    },
    txnId: String,
  },
  { timestamps: true }
);

// اسم الموديل "payments" حسب ما كتبتي
export default mongoose.model("payments", PaymentSchema);

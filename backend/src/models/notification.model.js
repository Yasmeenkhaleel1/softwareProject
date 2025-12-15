import mongoose from "mongoose";

const notificationSchema = new mongoose.Schema(
  {
    user: { type: mongoose.Schema.Types.ObjectId, ref: "User", index: true, required: true },
    title: String,
    body: String,
    data: { type: Object, default: {} },
    link: String,
    readAt: Date,
  },
  { timestamps: true }
);

export default mongoose.model("notifications", notificationSchema);

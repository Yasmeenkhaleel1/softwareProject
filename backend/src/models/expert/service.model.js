import mongoose from "mongoose";

const serviceSchema = new mongoose.Schema(
  {
    expert: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },
    title: {
      type: String,
      required: true,
      trim: true,
      maxlength: 120,
    },
    category: {
      type: String,
      required: true,
      trim: true, // مثال: "Design", "Consulting"
    },
    description: {
      type: String,
      required: true,
      maxlength: 5000,
    },
    price: {
      type: Number,
      required: true,
      min: 0,
    },
    currency: {
      type: String,
      default: "USD",
    },
    durationMinutes: {
      type: Number,
      required: true,
      min: 15, // مدة الجلسة/الخدمة
    },
    tags: [
      {
        type: String,
        trim: true,
        lowercase: true,
      },
    ],
    images: [
      {
        type: String, // روابط صور
      },
    ],
    isPublished: {
      type: Boolean,
      default: false, // إظهار/إخفاء
    },
    status: {
      type: String,
      enum: ["ACTIVE", "ARCHIVED"],
      default: "ACTIVE",
    },
    ratingAvg: {
      type: Number,
      default: 0,
    },
    ratingCount: {
      type: Number,
      default: 0,
    },

    ratings: [
  {
    userId: { type: mongoose.Schema.Types.ObjectId, ref: "User" },
    value: { type: Number, min: 1, max: 5 },
  },
],

    bookingsCount: {
      type: Number,
      default: 0,
    },
  },
  { timestamps: true }
);

// ✅ إصلاح الفهرس النصي (Text Index)
// الآن يمكن البحث في العنوان والوصف والكلمات داخل مصفوفة tags
serviceSchema.index({
  title: "text",
  description: "text",
  tags: "text",
});

const Service = mongoose.model("Service", serviceSchema);
export default Service;

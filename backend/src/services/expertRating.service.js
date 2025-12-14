// src/services/expertRating.service.js
import Service from "../models/expert/service.model.js";
import ExpertProfile from "../models/expert/expertProfile.model.js";
import mongoose from "mongoose";

/**
 * 🔄 يعيد حساب Rating البروفايل بناءً على كل الخدمات التابعة لنفس اليوزر
 * - userId: هو نفس الحقل expert في Service
 */
export async function updateExpertRatingByUserId(userId) {
  const userObjectId = new mongoose.Types.ObjectId(userId);

  // 🔹 كل الخدمات اللي إلها rating (ratingCount > 0)
  const services = await Service.find({
    expert: userObjectId,
    ratingCount: { $gt: 0 },
  }).select("ratingAvg ratingCount");

  if (!services.length) {
    // لو ما في ولا خدمة متقيّمة → صفر
    await ExpertProfile.updateMany(
      { userId: userObjectId },
      { $set: { ratingAvg: 0, ratingCount: 0 } }
    );
    return { ratingAvg: 0, ratingCount: 0 };
  }

  let totalWeighted = 0; // مجموع (متوسط الخدمة × عدد تقييماتها)
  let totalCount = 0;    // مجموع كل التقييمات

  for (const s of services) {
    const avg = s.ratingAvg || 0;
    const count = s.ratingCount || 0;
    totalWeighted += avg * count;
    totalCount += count;
  }

  const finalAvg = totalCount > 0 ? totalWeighted / totalCount : 0;

  // 🔁 نحدث كل البروفايلات التابعة لهذا اليوزر (approved, pending, draft)
  await ExpertProfile.updateMany(
    { userId: userObjectId },
    {
      $set: {
        ratingAvg: finalAvg,
        ratingCount: totalCount,
      },
    }
  );

  return { ratingAvg: finalAvg, ratingCount: totalCount };
}

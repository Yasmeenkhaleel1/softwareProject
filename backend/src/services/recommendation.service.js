// src/services/recommendation.service.js
import ExpertProfile from "../models/expert/expertProfile.model.js";
import Booking from "../models/booking.model.js";

export const getSmartRecommendations = async (userId) => {
  try {
    // 1. جلب أعلى الخبراء تقييماً
    const topRated = await ExpertProfile.find()
      .sort({ rating: -1 })
      .limit(4)
      .lean();

    // 2. جلب آخر اهتمامات المستخدم (مثلاً آخر خدمة حجزها)
    const lastBooking = await Booking.findOne({ customer: userId })
      .sort({ createdAt: -1 })
      .populate('service')
      .lean();

    let basedOnHistory = [];
    if (lastBooking && lastBooking.service) {
      // اقتراح خبراء من نفس تخصص آخر خدمة حجزها
      basedOnHistory = await ExpertProfile.find({
        specialty: lastBooking.service.category,
        _id: { $ne: lastBooking.expert } // استثناء الخبير الذي حجز عنده بالفعل
      }).limit(4).lean();
    }

    return {
      topRated,
      recommendedForYou: basedOnHistory.length > 0 ? basedOnHistory : topRated.slice(0, 2),
    };
  } catch (error) {
    throw error;
  }
};
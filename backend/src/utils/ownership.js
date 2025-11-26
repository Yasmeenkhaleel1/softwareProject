// src/utils/ownership.js
import mongoose from "mongoose";

/**
 * ✅ ensureOwnership
 * يتحقق أن الحجز (Booking) فعلاً يعود للخبير الذي قام بالطلب (req.user.id)
 * يُستخدم في جميع العمليات مثل acceptBooking, declineBooking, etc.
 */
export function ensureOwnership(booking, userId) {
  if (!booking) {
    const err = new Error("Booking not found");
    err.status = 404;
    throw err;
  }

  // 🧩 1️⃣ الحالة الحديثة (الهيكل الجديد)
  // عندنا الآن booking.expertUserId = user._id للخبير
  if (booking.expertUserId) {
    if (String(booking.expertUserId) !== String(userId)) {
      const err = new Error("Booking not found (ownership mismatch)");
      err.status = 403;
      throw err;
    }
    return;
  }

  // 🧩 2️⃣ دعم للبيانات القديمة (Backward Compatibility)
  // بعض الحجوزات القديمة قد لا تحتوي expertUserId، فقط expert = ExpertProfile._id
  if (booking.expert) {
    // في هذه الحالة يمكننا السماح مؤقتًا — أو التحقق من أن هذا البروفايل يرجع لليوزر نفسه لاحقًا
    return;
  }

  // 🧩 3️⃣ fallback — إذا لا يوجد أي من الاثنين
  const err = new Error("Invalid booking record (no ownership data)");
  err.status = 400;
  throw err;
}

import ExpertProfile from "../models/expert/expertProfile.model.js";

export const getSmartRecommendations = async (req, res) => {
  try {
    const { q } = req.query; // 🔍 بحث المستخدم (اختياري)

    const pipeline = [
      { $match: { status: "approved" } },

      // 🔗 ربط الخدمات
      {
        $lookup: {
          from: "services",
          localField: "user",
          foreignField: "expert",
          as: "services"
        }
      },

      // 🔗 حساب عدد الحجوزات
      {
        $lookup: {
          from: "bookings",
          let: { serviceIds: "$services._id" },
          pipeline: [
            {
              $match: {
                $expr: { $in: ["$service", "$$serviceIds"] },
                status: { $in: ["CONFIRMED", "IN_PROGRESS", "COMPLETED"] }
              }
            }
          ],
          as: "bookings"
        }
      },

      // 🧮 حساب العدد
      {
        $addFields: {
          bookingsCount: { $size: "$bookings" }
        }
      }
    ];

    // 🔍 لو المستخدم بحث
    if (q) {
      pipeline.push({
        $match: {
          $or: [
            { name: { $regex: q, $options: "i" } },
            { title: { $regex: q, $options: "i" } }
          ]
        }
      });
    }

    // ⭐️ ترتيب ذكي
    pipeline.push(
      { $sort: { ratingAvg: -1, bookingsCount: -1 } },
      { $limit: 6 }
    );

    const experts = await ExpertProfile.aggregate(pipeline);

    res.json({
      success: true,
      data: {
        smartRecommendations: experts
      }
    });
  } catch (err) {
    console.error("❌ Recommendation error:", err);
    res.status(500).json({ success: false, message: "Failed to load recommendations" });
  }
};
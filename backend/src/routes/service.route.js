import { Router } from "express";
import mongoose from "mongoose";
import Service from "../models/expert/service.model.js";
import { auth } from "../middleware/auth.js";

const router = Router();

/* =====================================================
   🟢 إنشاء خدمة جديدة
   ===================================================== */
router.post("/", auth(), async (req, res) => {
  try {
    console.log("🔹 Route hit:", req.method, req.originalUrl);
    const expertId = new mongoose.Types.ObjectId(req.user.id);
    const body = req.body || {};

    const doc = await Service.create({ ...body, expert: expertId });
    console.log("✅ Service created:", doc._id);

    res.status(201).json({ service: doc });
  } catch (e) {
    console.error("❌ Error creating service:", e.message);
    res.status(400).json({ error: e.message });
  }
});

/* =====================================================
   🟢 الحصول على جميع الخدمات الخاصة بالخبير (مع bookingsCount)
   ===================================================== */
router.get("/me", auth(), async (req, res) => {
  console.log("🔹 Route hit:", req.method, req.originalUrl);
  try {
    const expertId = new mongoose.Types.ObjectId(req.user.id);
    const { status, published, page = 1, limit = 20, q } = req.query;

    const match = { expert: expertId };
    if (status) match.status = status;
    if (published === "true") match.isPublished = true;
    if (published === "false") match.isPublished = false;

    if (q) {
      match.$text = { $search: q };
    }

    const skip = (Number(page) - 1) * Number(limit);

    const items = await Service.aggregate([
      { $match: match },
      { $sort: { updatedAt: -1 } },
      { $skip: skip },
      { $limit: Number(limit) },

      // 🧠 ادمج الخدمات بالحجوزات
      {
        $lookup: {
          from: "bookings",
          let: { serviceId: "$_id" },
          pipeline: [
            {
              $match: {
                $expr: { $eq: ["$service", "$$serviceId"] },
                status: { $in: ["CONFIRMED", "IN_PROGRESS", "COMPLETED"] }
              }
            },
            { $count: "count" }
          ],
          as: "bk"
        }
      },

      // 🧮 احسب العدد أو صفر
      {
        $addFields: {
          bookingsCount: {
            $ifNull: [{ $arrayElemAt: ["$bk.count", 0] }, 0]
          }
        }
      },

      // 🚮 احذف الحقل الوسيط
      { $project: { bk: 0 } }
    ]);

    const total = await Service.countDocuments(match);

    console.log("✅ Services found:", items.length);
    res.json({ items, total, page: Number(page), limit: Number(limit) });
  } catch (e) {
    console.error("❌ Fetch error:", e.message);
    res.status(500).json({ error: e.message });
  }
});


/* =====================================================
   🟢 تعديل خدمة موجودة
   ===================================================== */
router.put("/:id", auth(), async (req, res) => {
  console.log("🔹 Route hit:", req.method, req.originalUrl);
  try {
    const { id } = req.params;
    const updated = await Service.findOneAndUpdate(
      { _id: id, expert: req.user.id, status: "ACTIVE" },
      req.body,
      { new: true }
    );

    if (!updated) return res.status(404).json({ error: "Not found" });

    console.log("✅ Service updated:", updated._id);
    res.json({ service: updated });
  } catch (e) {
    console.error("❌ Update error:", e.message);
    res.status(400).json({ error: e.message });
  }
});

/* =====================================================
   🟢 نشر أو إخفاء خدمة (Toggle Publish)
   ===================================================== */
router.patch("/:id/publish", auth(), async (req, res) => {
  console.log("🔹 Route hit:", req.method, req.originalUrl);
  try {
    const { id } = req.params;
    const { isPublished } = req.body;

    const updated = await Service.findOneAndUpdate(
      { _id: id, expert: req.user.id, status: "ACTIVE" },
      { isPublished: !!isPublished },
      { new: true }
    );

    if (!updated) return res.status(404).json({ error: "Not found" });

    console.log("✅ Service publish toggled:", updated._id);
    res.json({ service: updated });
  } catch (e) {
    console.error("❌ Publish toggle error:", e.message);
    res.status(400).json({ error: e.message });
  }
});

/* =====================================================
   🟢 أرشفة خدمة (إخفاؤها من المتجر)
   ===================================================== */
router.delete("/:id", auth(), async (req, res) => {
  console.log("🔹 Route hit:", req.method, req.originalUrl);
  try {
    const { id } = req.params;

    const updated = await Service.findOneAndUpdate(
      { _id: id, expert: req.user.id, status: "ACTIVE" },
      { status: "ARCHIVED", isPublished: false },
      { new: true }
    );

    if (!updated) return res.status(404).json({ error: "Not found" });

    console.log("✅ Service archived:", updated._id);
    res.json({ service: updated });
  } catch (e) {
    console.error("❌ Archive error:", e.message);
    res.status(400).json({ error: e.message });
  }
});

/* =====================================================
   🟢 فك الأرشفة (إرجاع الخدمة من ARCHIVED إلى ACTIVE)
   ===================================================== */
router.patch("/:id/unarchive", auth(), async (req, res) => {
  console.log("🔹 Route hit:", req.method, req.originalUrl);
  try {
    const { id } = req.params;

    // ✅ تحديث الخدمة من ARCHIVED إلى ACTIVE
    const updated = await Service.findOneAndUpdate(
      { _id: id, expert: req.user.id, status: "ARCHIVED" },
      { status: "ACTIVE", isPublished: false },
      { new: true }
    );

    if (!updated) {
      return res.status(404).json({ error: "Archived service not found" });
    }

    console.log("✅ Service unarchived:", updated._id);
    res.json({ message: "Service restored successfully", service: updated });
  } catch (e) {
    console.error("❌ Unarchive error:", e.message);
    res.status(400).json({ error: e.message });
  }
});


/* =====================================================
   🟢 إحصائيات مختصرة للخبير
   ===================================================== */
router.get("/me/stats", auth(), async (req, res) => {
  console.log("🔹 Route hit:", req.method, req.originalUrl);
  try {
    const expert = req.user.id;

    const [total, active, published, archived] = await Promise.all([
      Service.countDocuments({ expert }),
      Service.countDocuments({ expert, status: "ACTIVE" }),
      Service.countDocuments({ expert, isPublished: true, status: "ACTIVE" }),
      Service.countDocuments({ expert, status: "ARCHIVED" }),
    ]);

    console.log("✅ Stats calculated:", { total, active, published, archived });
    res.json({ total, active, published, archived });
  } catch (e) {
    console.error("❌ Stats error:", e.message);
    res.status(500).json({ error: e.message });
  }
});

/* =====================================================
   🟢 استنساخ خدمة (Duplicate)
   ===================================================== */
router.post("/:id/duplicate", auth(), async (req, res) => {
  console.log("🔹 Route hit:", req.method, req.originalUrl);
  try {
    const { id } = req.params;
    const original = await Service.findOne({ _id: id, expert: req.user.id });

    if (!original) return res.status(404).json({ error: "Not found" });

    const copy = original.toObject();
    delete copy._id;
    copy.title = `${copy.title} (Copy)`;
    copy.isPublished = false;
    copy.status = "ACTIVE";
    copy.createdAt = new Date();
    copy.updatedAt = new Date();

    const newService = await Service.create(copy);

    console.log("✅ Service duplicated:", newService._id);
    res.status(201).json({ service: newService });
  } catch (e) {
    console.error("❌ Duplicate error:", e.message);
    res.status(400).json({ error: e.message });
  }
});

// ✅ تقييم خدمة
router.post("/:id/rate", auth(), async (req, res) => {
  try {
    const { rating } = req.body;
    const userId = req.user.id;
    const service = await Service.findById(req.params.id);
    if (!service) return res.status(404).json({ message: "Service not found" });

    if (rating < 1 || rating > 5)
      return res.status(400).json({ message: "Rating must be between 1 and 5" });

    // 🔹 تحقق إذا المستخدم قيّم من قبل
    const existing = service.ratings.find(r => r.userId.toString() === userId);
    if (existing) {
      existing.value = rating; // تحديث تقييمه القديم
    } else {
      service.ratings.push({ userId, value: rating });
      service.ratingCount = service.ratings.length;
    }

    // 🔹 حساب المتوسط الجديد
    const total = service.ratings.reduce((sum, r) => sum + r.value, 0);
    service.ratingAvg = total / service.ratingCount;

    await service.save();
    res.json({ message: "Rating updated successfully", ratingAvg: service.ratingAvg });
  } catch (err) {
    console.error("❌ Rating error:", err);
    res.status(500).json({ message: "Failed to update rating", error: err.message });
  }
});

/* =====================================================
   🟢 PUBLIC SEARCH (بدون توكن) - للعميل في صفحة البحث
   ===================================================== */
router.get("/public/search", async (req, res) => {
  try {
    const { q = "", category, sort = "rating_desc" } = req.query;

    const query = { 
      isPublished: true, 
      status: "ACTIVE" 
    };

    // 🔍 بحث نصي
    if (q && q.trim().length > 0) {
      query.$or = [
        { title: { $regex: q, $options: "i" } },
        { category: { $regex: q, $options: "i" } },
        { description: { $regex: q, $options: "i" } }
      ];
    }

    // 🎯 فلترة حسب التصنيف
    if (category && category !== "All") {
      query.category = category;
    }

    // ⭐ جلب الخِدمات مع الخبير
    const items = await Service.find(query)
      .populate("expert", "name specialization profileImageUrl ratingAvg")
      .lean();

    // 🔽 ترتيب النتائج
    if (sort === "price_asc") items.sort((a, b) => a.price - b.price);
    if (sort === "price_desc") items.sort((a, b) => b.price - a.price);
    if (sort === "name_az") items.sort((a, b) => a.title.localeCompare(b.title));
    if (sort === "name_za") items.sort((a, b) => b.title.localeCompare(a.title));
    if (sort === "rating_desc") items.sort((a, b) => (b.ratingAvg || 0) - (a.ratingAvg || 0));

    return res.json({
      count: items.length,
      items,
    });
  } catch (e) {
    console.error("❌ PUBLIC SEARCH ERROR:", e);
    return res.status(500).json({ message: "Search failed", error: e.message });
  }
});

export default router;

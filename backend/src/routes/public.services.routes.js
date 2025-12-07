import express from "express";
import Service from "../models/expert/service.model.js";
import User from "../models/user/user.model.js";
import ExpertProfile from "../models/expert/expertProfile.model.js";  // ✅ أضف هذا السطر
import mongoose from "mongoose";

const router = express.Router();



/* ==========================================================================
   🔍 Public Search — Customer side
   GET /api/public/services/search?q=design&category=Design&sort=price_asc
   ========================================================================== */

router.get("/public/services/search", async (req, res) => {
  try {
    const { q, category, sort } = req.query;

    const match = {
      status: "ACTIVE",
      isPublished: true,
    };

    // بحث نصي
    if (q) match.$text = { $search: q };

    // فلترة حسب الكاتيجوري
    if (category && category !== "All") {
      match.category = category;
    }

    // 1) جلب الخدمات + الـ User (صاحب الخدمة)
    let query = Service.find(match).populate({
      path: "expert",
      model: "User",
      select: "name profilePic email", // لاحقاً ممكن نعرض الإيميل
    });

    // 2) الترتيب
    if (sort === "price_asc") query = query.sort({ price: 1 });
    else if (sort === "price_desc") query = query.sort({ price: -1 });
    else query = query.sort({ ratingAvg: -1 }); // top rated

    let items = await query.lean();

    // لو ما في خدمات خلص رجع فاضي
    if (!items.length) {
      return res.json({ success: true, items: [] });
    }

    // 3) اجمع userId تبع كل خبير (مع حماية من null)
    const expertIds = items
      .filter((i) => i.expert && i.expert._id)
      .map((i) => i.expert._id.toString());

    if (!expertIds.length) {
      // خدمات بدون خبير (نادرة، بس سلامة)
      return res.json({ success: true, items });
    }

    // 4) جبلي الـ ExpertProfile الموافق لكل userId وموافق عليه
    const profiles = await ExpertProfile.find({
      userId: { $in: expertIds },
      status: "approved",
    }).lean();

    const profileMap = {};
    profiles.forEach((p) => {
      profileMap[p.userId.toString()] = p;
    });

    // 5) دمج بيانات البروفايل داخل expert نفسه
    items = items.map((i) => {
      const expert = i.expert || {};
      const key = expert._id ? expert._id.toString() : null;
      const profile = key ? profileMap[key] : null;

      if (!profile) {
        // ما في بروفايل → رجّع الخدمة زي ما هي
        return i;
      }

      const mergedExpert = {
        ...expert,
        // اولوية لاسم البروفايل لو user.name فاضي
        name: expert.name && expert.name.trim().length > 0
          ? expert.name
          : profile.name,
        // صورة البروفايل من ExpertProfile
        profileImageUrl:
          profile.profileImageUrl ||
          expert.profileImageUrl ||
          expert.profilePic ||
          null,
      };

      return {
        ...i,
        expert: mergedExpert,
        expertProfile: profile, // لو احتجناها بتفاصيل أخرى
      };
    });

    return res.json({ success: true, items });
  } catch (err) {
    console.error("❌ Search error:", err);
    res.status(500).json({ message: "Server error" });
  }
});

export default router;




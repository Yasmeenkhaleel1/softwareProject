import express from "express";
import ExpertProfile from "../models/expertProfile.model.js";
import Service from "../models/service.model.js";
import SearchHistory from "../models/searchHistory.model.js";
import { auth } from "../middleware/auth.js"; // اذا عندك توكن

const router = express.Router();

// GET /api/search?query=logo
router.get("/", auth, async (req, res) => {
  try {
    const userId = req.user._id;
    const q = req.query.query?.toLowerCase() || "";

    // سجل البحث
    if (q.trim() !== "") {
      await SearchHistory.create({
        userId,
        keyword: q,
      });
    }

    // ======= البحث في الخبراء ===========
    const experts = await ExpertProfile.find({
      $or: [
        { name: { $regex: q, $options: "i" } },
        { specialization: { $regex: q, $options: "i" } },
        { location: { $regex: q, $options: "i" } },
      ],
      status: "approved"
    })
    .select("name specialization profileImageUrl ratingAvg ratingCount")
    .lean();

    // ======= البحث في الخدمات ===========
    const services = await Service.find({
  $or: [
    { title: { $regex: q, $options: "i" } },
    { category: { $regex: q, $options: "i" } },
    { tags: { $regex: q, $options: "i" } },
    { description: { $regex: q, $options: "i" } }
  ],
  status: "ACTIVE",
  isPublished: true
})
.populate({
  path: "expert",
  model: "ExpertProfile",
  select: "name specialization profileImageUrl ratingAvg"
})
.lean();


    // ترتيب حسب أعلى ratingAvg
    services.sort((a, b) => (b.ratingAvg ?? 0) - (a.ratingAvg ?? 0));

    // ======= اخر عمليات البحث ===========
    const history = await SearchHistory.find({ userId })
      .sort({ createdAt: -1 })
      .limit(5)
      .lean();

    // ======= اقتراحات ===========
    const suggestions = [
      "AI", "Design", "Marketing", "Mobile Apps",
      "Data Science", "Branding", "Flutter", "Logos"
    ];

    res.json({
      experts,
      services,
      history,
      suggestions
    });

  } catch (e) {
    console.error("SEARCH ERROR:", e);
    res.status(500).json({ error: "Search failed" });
  }
});

export default router;

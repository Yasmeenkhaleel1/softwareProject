import mongoose from "mongoose";
import User from "../models/user/user.model.js";
import Service from "../models/expert/service.model.js";
import ExpertProfile from "../models/expert/expertProfile.model.js";

/* ============================================================================
 * List approved experts (for customers) + Pagination
 * GET /api/customers/experts?page=1&limit=10
 * ========================================================================== */
export const listApprovedExpertsForCustomers = async (req, res) => {
  try {
    const { page = 1, limit = 10 } = req.query;

    const experts = await ExpertProfile
      .find({ status: "approved" })
      .select("name specialization experience location profileImageUrl bio userId ratingAvg ratingCount")
      .skip((+page - 1) * +limit)
      .limit(+limit);

    const total = await ExpertProfile.countDocuments({ status: "approved" });

    res.json({
      success: true,
      total,
      page: +page,
      pages: Math.ceil(total / +limit),
      experts,
    });
  } catch (err) {
    console.error("❌ Error fetching experts for customers:", err);
    res.status(500).json({ message: "Server error" });
  }
};

/* ============================================================================
 * Me (customer)
 * ========================================================================== */
export const getMyCustomerProfile = async (req, res) => {
  try {
    const user = await User.findById(req.user.id).select("-passwordHash -verificationCode");
    if (!user) return res.status(404).json({ message: "User not found" });
    res.json({ success: true, user });
  } catch (err) {
    console.error("❌ Error fetching customer profile:", err);
    res.status(500).json({ message: "Server error" });
  }
};

export const updateMyCustomerProfile = async (req, res) => {
  try {
    const { name, age, gender, profilePic } = req.body;
    const user = await User.findByIdAndUpdate(
      req.user.id,
      { name, age, gender, profilePic },
      { new: true }
    ).select("-passwordHash -verificationCode");

    if (!user) return res.status(404).json({ message: "User not found" });
    res.json({ success: true, message: "Profile updated", user });
  } catch (err) {
    console.error("❌ Error updating profile:", err);
    res.status(500).json({ message: "Server error" });
  }
};

/* ============================================================================
 * Public customer profile (optional)
 * ========================================================================== */
export const viewCustomerProfile = async (req, res) => {
  try {
    const { userId } = req.params;
    const user = await User.findById(userId).select("name age gender profilePic role");
    if (!user) return res.status(404).json({ message: "Customer not found" });
    res.json({ success: true, user });
  } catch (err) {
    console.error("❌ Error fetching public profile:", err);
    res.status(500).json({ message: "Server error" });
  }
};

/* ============================================================================
 * Expert public profile + services (for customers)
 * ========================================================================== */

// GET /api/experts/:id  → id = ExpertProfile._id
export const getExpertPublicProfile = async (req, res) => {
  try {
    const { id } = req.params;

    if (!mongoose.Types.ObjectId.isValid(id)) {
      return res.status(400).json({ message: "Invalid expert ID" });
    }

    const expert = await ExpertProfile
      .findById(id)
      .select("name specialization experience location profileImageUrl bio status userId");

    if (!expert || expert.status !== "approved") {
      return res.status(404).json({ message: "Expert not found" });
    }

    // 🟢 أضف عدد الخدمات المنشورة
    const serviceCount = await Service.countDocuments({
      expert: expert.userId,
      status: "ACTIVE",
      isPublished: true,
    });

    res.json({ success: true, expert, serviceCount });
  } catch (err) {
    console.error("❌ Error fetching expert profile:", err);
    res.status(500).json({ message: "Server error" });
  }
};

// GET /api/experts/:id/services  → id = ExpertProfile._id
export const listPublishedServicesForExpert = async (req, res) => {
  try {
    const { id } = req.params;

    if (!mongoose.Types.ObjectId.isValid(id)) {
      return res.status(400).json({ message: "Invalid expert ID" });
    }

    // Convert ExpertProfile._id → owning User._id (because Service.expert ref: "User")
    const profile = await ExpertProfile.findById(id).select("status userId");
    if (!profile || profile.status !== "approved") {
      return res.status(404).json({ message: "Expert not found" });
    }

    const expertUserId = profile.userId; // <-- CORRECT FIELD

    const items = await Service.find({
      expert: new mongoose.Types.ObjectId(expertUserId),
      status: "ACTIVE",
      isPublished: true,
    })
      .sort({ updatedAt: -1 })
      .select(
        "title category description price currency durationMinutes images ratingAvg ratingCount status isPublished updatedAt"
      );

    console.log(`✅ Found ${items.length} services for expertUser ${expertUserId} (profile ${id})`);
    res.json({ success: true, items });
  } catch (err) {
    console.error("❌ Error fetching services for expert:", err);
    res.status(500).json({ message: "Server error" });
  }
};

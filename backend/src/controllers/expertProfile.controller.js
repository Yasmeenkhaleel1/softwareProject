// src/controllers/expertProfile.controller.js
import ExpertProfile from "../models/expert/expertProfile.model.js";

// ===== Create new expert profile =====
export const createExpertProfile = async (req, res) => {
  try {
    // 🔐 خذ الـ userId من التوكن (اللي جهزه الميدلوير auth)
    const userId = req.user?.id;
    if (!userId) return res.status(401).json({ message: "Unauthorized" });

    const {
      name,
      bio,
      specialization,
      experience,
      location,
      certificates = [],
      gallery = [],
      profileImageUrl,
    } = req.body;

    // 🧩 تحقق إن المستخدم ما عنده بروفايل سابق
    const existing = await ExpertProfile.findOne({ userId });
    if (existing && existing.status === "pending") {
      return res
        .status(400)
        .json({ message: "You already have a pending profile under review." });
    }
    if (existing && existing.status === "approved") {
      return res
        .status(400)
        .json({ message: "You already have an approved profile." });
    }

    // 🏗️ إنشاء بروفايل جديد
    const profile = new ExpertProfile({
      userId,
      name,
      bio,
      specialization,
      experience,
      location,
      certificates,
      gallery,
      profileImageUrl,
      status: "pending",
    });

    await profile.save();
    return res
      .status(201)
      .json({ message: "Profile submitted for admin review.", profile });
  } catch (err) {
    console.error("createExpertProfile error:", err);
    return res
      .status(500)
      .json({ message: "Internal server error", error: err.message });
  }
};

// ===== Get my profile =====
export const getMyExpertProfile = async (req, res) => {
  try {
    const userId = req.user?.id;
    if (!userId) return res.status(401).json({ message: "Unauthorized" });

    const profile = await ExpertProfile.findOne({ userId });
    if (!profile) return res.status(404).json({ message: "No profile found" });

    return res.json({ profile });
  } catch (err) {
    console.error("getMyExpertProfile error:", err);
    return res
      .status(500)
      .json({ message: "Internal server error", error: err.message });
  }
};

// ===== Update my profile (only when pending) =====
export const updateMyExpertProfile = async (req, res) => {
  try {
    const userId = req.user?.id;
    const { profileId } = req.params;

    const profile = await ExpertProfile.findOne({ _id: profileId, userId });
    if (!profile) return res.status(404).json({ message: "Profile not found" });

    if (profile.status !== "pending") {
      return res
        .status(400)
        .json({ message: "Only pending profiles can be updated." });
    }

    const fields = [
      "name",
      "bio",
      "specialization",
      "experience",
      "location",
      "certificates",
      "gallery",
      "profileImageUrl",
    ];
    for (const f of fields) {
      if (req.body[f] !== undefined) profile[f] = req.body[f];
    }

    await profile.save();
    return res.json({ message: "Profile updated (still pending).", profile });
  } catch (err) {
    console.error("updateMyExpertProfile error:", err);
    return res
      .status(500)
      .json({ message: "Internal server error", error: err.message });
  }
};

// ===== Admin endpoints =====
export const listExpertProfiles = async (req, res) => {
  try {
    const { status } = req.query;
    const filter = status ? { status } : {};
    const profiles = await ExpertProfile.find(filter).sort({ createdAt: -1 });
    return res.json(profiles);
  } catch (err) {
    console.error("listExpertProfiles error:", err);
    return res
      .status(500)
      .json({ message: "Internal server error", error: err.message });
  }
};

export const approveExpertProfile = async (req, res) => {
  try {
    const { id } = req.params;
    const profile = await ExpertProfile.findById(id);
    if (!profile) return res.status(404).json({ message: "Profile not found" });

    profile.status = "approved";
    profile.rejectionReason = undefined;
    await profile.save();
    return res.json({ message: "Expert profile approved.", profile });
  } catch (err) {
    console.error("approveExpertProfile error:", err);
    return res
      .status(500)
      .json({ message: "Internal server error", error: err.message });
  }
};

export const rejectExpertProfile = async (req, res) => {
  try {
    const { id } = req.params;
    const { reason } = req.body;

    const profile = await ExpertProfile.findById(id);
    if (!profile) return res.status(404).json({ message: "Profile not found" });

    profile.status = "rejected";
    profile.rejectionReason = reason || "No reason provided";
    await profile.save();
    return res.json({ message: "Expert profile rejected.", profile });
  } catch (err) {
    console.error("rejectExpertProfile error:", err);
    return res
      .status(500)
      .json({ message: "Internal server error", error: err.message });
  }
};

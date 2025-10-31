// src/controllers/expertProfile.controller.js
import ExpertProfile from "../models/expert/expertProfile.model.js";
import User from "../models/user/user.model.js"; // ✅ استدعاء موديل المستخدم

// ===== Create new expert profile =====
export const createExpertProfile = async (req, res) => {
  try {
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

    // ✅ تحديث حالة المستخدم: أصبح لديه بروفايل
    await User.findByIdAndUpdate(userId, { hasProfile: true });

    return res.status(201).json({
      message: "Profile submitted for admin review.",
      profile,
    });
  } catch (err) {
    console.error("createExpertProfile error:", err);
    return res.status(500).json({ message: "Internal server error", error: err.message });
  }
};

// ===== Get my profile (updated to return user + profile) =====
// ===== Get my profile (returning all states properly) =====
export const getMyExpertProfile = async (req, res) => {
  try {
    const userId = req.user?.id;
    if (!userId) return res.status(401).json({ message: "Unauthorized" });

    const user = await User.findById(userId).select(
      "name email gender age role profilePic isVerified isApproved"
    );
    if (!user) return res.status(404).json({ message: "User not found" });

    // ✅ نجلب كل الحالات لنعرضها حسب المنطق
    const [approved, pending, draft] = await Promise.all([
      ExpertProfile.findOne({ userId, status: "approved" }),
      ExpertProfile.findOne({ userId, status: "pending" }),
      ExpertProfile.findOne({ userId, status: "draft" }),
    ]);

    // ✅ نختار البروفايل الحالي الذي سيُعرض
    const activeProfile = approved || pending || draft;

    if (!activeProfile) {
      return res.status(404).json({ message: "No profile found" });
    }

    return res.status(200).json({
      user,
      approvedProfile: approved,
      pendingProfile: pending,
      draftProfile: draft,
      profile: activeProfile, // هذا الذي يعرضه الخبير في الـ Dashboard
    });
  } catch (err) {
    console.error("getMyExpertProfile error:", err);
    return res.status(500).json({
      message: "Internal server error",
      error: err.message,
    });
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
      return res.status(400).json({ message: "Only pending profiles can be updated." });
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
    return res.status(500).json({ message: "Internal server error", error: err.message });
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
    return res.status(500).json({ message: "Internal server error", error: err.message });
  }
};

// ===== Approve profile (fixed version) =====
export const approveExpertProfile = async (req, res) => {
  try {
    const { id } = req.params;

    // 1️⃣ جلب البروفايل المستهدف
    const profile = await ExpertProfile.findById(id);
    if (!profile) return res.status(404).json({ message: "Profile not found" });

    // 2️⃣ السماح فقط بالموافقة على البروفايلات pending
    if (profile.status !== "pending") {
      return res.status(400).json({ message: "Only pending profiles can be approved." });
    }

    // 3️⃣ جلب المستخدم المرتبط بالبروفايل
    const user = await User.findById(profile.userId);
    if (!user) return res.status(404).json({ message: "User not found" });

    // ✅ ملاحظة مهمة:
    // نؤرشف فقط البروفايلات السابقة (approved أو pending)
    // ولكن بعد التأكد أن هذا الـ profile الحالي لم تتم الموافقة عليه بعد
    await ExpertProfile.updateMany(
      {
        userId: user._id,
        _id: { $ne: profile._id }, // لا تلمس الحالي
        status: { $in: ["approved", "pending"] },
      },
      { $set: { status: "archived" } }
    );

    // ✅ نحدث حالة هذا البروفايل بعد الأرشفة
    profile.status = "approved";
    profile.rejectionReason = undefined;
    await profile.save();

    // ✅ نحدث المستخدم
    user.isApproved = true;
    await user.save();

    // ✅ إرسال إشعار للخبير
    await Notification.create({
      userId: user._id,
      title: "Profile Approved ✅",
      message: "Your expert profile has been approved by the admin. You can now access all expert features.",
      type: "success",
    });

    return res.json({
      message: "✅ Expert profile approved successfully.",
      user,
      profile,
    });
  } catch (err) {
    console.error("approveExpertProfile error:", err);
    return res.status(500).json({
      message: "Internal server error",
      error: err.message,
    });
  }
};



// ===== Reject profile =====
export const rejectExpertProfile = async (req, res) => {
  try {
    const { id } = req.params;
    const { reason } = req.body;

    const profile = await ExpertProfile.findById(id);
    if (!profile) return res.status(404).json({ message: "Profile not found" });

    profile.status = "rejected";
    profile.rejectionReason = reason || "No reason provided";
    await profile.save();

    // ✅ عند الرفض: تأكد من بقاء isApproved = false
    await User.findByIdAndUpdate(profile.userId, { isApproved: false });

    return res.json({ message: "Expert profile rejected.", profile });
  } catch (err) {
    console.error("rejectExpertProfile error:", err);
    return res.status(500).json({ message: "Internal server error", error: err.message });
  }
};

// ===== Create Draft from approved profile =====
export const createDraftFromApproved = async (req, res) => {
  try {
    const userId = req.user.id;

    // 🔹 لو عنده draft جاهز، رجّعه بدون إنشاء جديد
    const existingDraft = await ExpertProfile.findOne({ userId, status: "draft" });
    if (existingDraft) return res.json({ draft: existingDraft, created: false });

    // 🔹 لا يمكن إنشاء draft أثناء وجود pending
    const pending = await ExpertProfile.findOne({ userId, status: "pending" });
    if (pending) return res.status(400).json({ message: "Profile under review." });

    // 🔹 ابحث عن approved لنسخه
    const approved = await ExpertProfile.findOne({ userId, status: "approved" });

    const draft = new ExpertProfile({
      userId,
      name: approved?.name ?? "",
      bio: approved?.bio ?? "",
      specialization: approved?.specialization ?? "",
      experience: approved?.experience ?? 0,
      location: approved?.location ?? "",
      certificates: approved?.certificates ?? [],
      gallery: approved?.gallery ?? [],
      profileImageUrl: approved?.profileImageUrl ?? "",
      status: "draft",
    });

    await draft.save();
    return res.status(201).json({ draft, created: true });
  } catch (err) {
    console.error("createDraftFromApproved error:", err);
    return res.status(500).json({ message: "Internal server error", error: err.message });
  }
};

// ===== Update my draft =====
export const updateMyDraft = async (req, res) => {
  try {
    const userId = req.user.id;
    const { draftId } = req.params;

    const draft = await ExpertProfile.findOne({ _id: draftId, userId, status: "draft" });
    if (!draft) return res.status(404).json({ message: "Draft not found" });

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
      if (req.body[f] !== undefined) draft[f] = req.body[f];
    }

    await draft.save();
    return res.json({ message: "Draft saved successfully.", draft });
  } catch (err) {
    console.error("updateMyDraft error:", err);
    return res.status(500).json({ message: "Internal server error", error: err.message });
  }
};

// ===== Submit draft for review =====
export const submitDraftForReview = async (req, res) => {
  try {
    const userId = req.user.id;
    const { draftId } = req.params;

    const draft = await ExpertProfile.findOne({ _id: draftId, userId, status: "draft" });
    if (!draft) return res.status(404).json({ message: "Draft not found" });

    draft.status = "pending";
    await draft.save();

    return res.json({ message: "Draft submitted for admin review.", draft });
  } catch (err) {
    console.error("submitDraftForReview error:", err);
    return res.status(500).json({ message: "Internal server error", error: err.message });
  }
};


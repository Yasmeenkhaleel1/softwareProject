import User from "../models/user/user.model.js";
import ExpertProfile from "../models/expert/expertProfile.model.js";

// ✅ GET /customers/experts  --> لعرض جميع الخبراء الموافق عليهم
export const listApprovedExpertsForCustomers = async (req, res) => {
  try {
    const experts = await ExpertProfile.find({ status: "approved" }).select(
      "name specialization experience location profileImageUrl bio"
    );

    res.json({ success: true, experts });
  } catch (err) {
    console.error("❌ Error fetching experts for customers:", err);
    res.status(500).json({ message: "Server error" });
  }
};

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

// ✅ PATCH /customers/me
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

// ✅ GET /customers/view/:userId
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
// src/controllers/stripeConnect.controller.js
import Stripe from "stripe";
import ExpertProfile from "../models/expert/expertProfile.model.js";

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY);

// 🔹 إنشاء أو استرجاع حساب Stripe Connect + إرجاع رابط Onboarding
export async function createConnectAccountLink(req, res) {
  try {
    const userId = req.user.id; // اليوزر الحالي (لازم يكون خبير)
    const profile = await ExpertProfile.findOne({ userId }).lean();

    if (!profile) {
      return res.status(404).json({ message: "Expert profile not found" });
    }

    let connectId = profile.stripeConnectId;

    // لو ما عنده حساب Stripe Connect ننشئ واحد
    if (!connectId) {
      const account = await stripe.accounts.create({
        type: "express",
        country: "US", // لأن حساب المنصّة US
        email: req.user.email,
        capabilities: {
          card_payments: { requested: true },
          transfers: { requested: true },
        },
        business_type: "individual",
      });

      connectId = account.id;
      await ExpertProfile.updateOne(
        { _id: profile._id },
        { stripeConnectId: connectId }
      );
    }

    // 🔗 إنشاء رابط Onboarding
    const frontendUrl = process.env.FRONTEND_URL || "http://localhost:3000";

    const accountLink = await stripe.accountLinks.create({
      account: connectId,
      refresh_url: `${frontendUrl}/stripe/refresh`,
      return_url: `${frontendUrl}/stripe/return`,
      type: "account_onboarding",
    });

    return res.json({ url: accountLink.url });
  } catch (err) {
    console.error("createConnectAccountLink error", err);
    res.status(500).json({ message: err.message });
  }
}

// 🔹 معرفة حالة حساب Stripe للخبير: جاهز يستقبل فلوس ولا لأ؟
export async function getConnectStatus(req, res) {
  try {
    const userId = req.user.id;
    const profile = await ExpertProfile.findOne({ userId });

    if (!profile || !profile.stripeConnectId) {
      return res.json({ connected: false });
    }

    const account = await stripe.accounts.retrieve(profile.stripeConnectId);

    const payoutsEnabled = account.payouts_enabled && account.charges_enabled;

    if (payoutsEnabled !== profile.stripePayoutsEnabled) {
      profile.stripePayoutsEnabled = payoutsEnabled;
      await profile.save();
    }

    res.json({
      connected: true,
      payoutsEnabled,
      detailsSubmitted: account.details_submitted,
    });
  } catch (err) {
    console.error("getConnectStatus error", err);
    res.status(500).json({ message: err.message });
  }
}

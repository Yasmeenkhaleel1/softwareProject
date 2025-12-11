// src/controllers/payments.stripe.js
import Stripe from "stripe";
import Payment from "../models/payment.model.js";
import ExpertProfile from "../models/expert/expertProfile.model.js";

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY);

export async function createIntent(req, res) {
  try {
    const {
      amount,
      currency = "USD",
      customer,
      expertProfileId,  // ExpertProfile._id
      service,
      booking,
    } = req.body || {};

    if (!amount || !expertProfileId) {
      return res.status(400).json({ error: "amount and expertProfileId are required" });
    }

    const expertProfile = await ExpertProfile.findById(expertProfileId).lean();
    if (!expertProfile || !expertProfile.stripeConnectId) {
      return res
        .status(400)
        .json({ error: "Expert is not connected to Stripe yet" });
    }

    const totalAmountCents = Math.round(amount * 100);
    const platformFeeCents = Math.round(amount * 0.1 * 100); // 10% للمنصة

    const intent = await stripe.paymentIntents.create({
      amount: totalAmountCents,
      currency,
      capture_method: "manual", // AUTH فقط
      application_fee_amount: platformFeeCents, // 🔥 نسبة المنصة
      transfer_data: {
        destination: expertProfile.stripeConnectId, // 🔥 الباقي يذهب للخبير
      },
    });

    const pay = await Payment.create({
      amount,
      currency,
      status: "AUTHORIZED",
      txnId: intent.id,
      customer,
      expert: expertProfile.userId, // الخبير صاحب الحساب
      service,
      booking,
      platformFee: platformFeeCents / 100,
      netToExpert: amount - platformFeeCents / 100,
      timeline: [{ action: "AUTHORIZED", by: "STRIPE", at: new Date() }],
    });

    res.json({
      clientSecret: intent.client_secret,
      paymentId: pay._id,
    });
  } catch (err) {
    console.error("createIntent error", err);
    res.status(500).json({ error: err.message });
  }
}

// 🚀 Confirm & attach card to payment intent
export async function confirmIntent(req, res) {
  try {
    const { paymentId, paymentIntentId } = req.body;

    if (!paymentId) {
      return res.status(400).json({
        error: "paymentId is required",
      });
    }

    const payment = await Payment.findById(paymentId);
    if (!payment) {
      return res.status(404).json({ error: "Payment not found" });
    }

    // نحدد ID الـ PaymentIntent:
    const intentId = paymentIntentId || payment.txnId;
    if (!intentId) {
      return res.status(400).json({ error: "Missing paymentIntent id" });
    }

    // 🔍 فقط نعمل retrieve، ما بنعمل confirm من جديد
    const intent = await stripe.paymentIntents.retrieve(intentId);

    if (intent.status !== "requires_capture") {
      return res.status(400).json({
        error: "PaymentIntent not ready for capture. Status: " + intent.status,
      });
    }

    // ✅ كل شيء تمام → نحدّث الـ DB
    payment.status = "CONFIRMED";
    payment.timeline.push({
      action: "CONFIRMED",
      by: "SYSTEM",
      at: new Date(),
      meta: { stripeStatus: intent.status },
    });
    await payment.save();

    return res.json({
      status: "CONFIRMED",
      stripeStatus: intent.status,
      nextStep: "Now call /api/payments/capture to finalize transfer",
    });
  } catch (err) {
    console.error("❌ confirmIntent:", err);
    res.status(500).json({ error: err.message });
  }
}





export async function refundPayment(req, res) {
  try {
    const { paymentId, amount } = req.body;

    const payment = await Payment.findById(paymentId);
    if (!payment) {
      return res.status(404).json({ error: "Payment not found" });
    }

    if (payment.status !== "CAPTURED") {
      return res.status(400).json({
        error: "Only captured payments can be refunded",
      });
    }

    const refundAmountCents = amount
      ? Math.round(amount * 100)
      : Math.round(payment.amount * 100);

    const refund = await stripe.refunds.create({
      payment_intent: payment.txnId,
      amount: refundAmountCents,

      // 🟦 الخيار الأفضل: خلي Stripe يقسم الخسارة
      refund_application_fee: true,
      reverse_transfer: true,
    });

    // 🟦 تحديث القيم محلياً
    const refundAmount = refundAmountCents / 100;

    payment.status = "REFUND_PENDING";
    payment.refundedAmount += refundAmount;

    payment.timeline.push({
      action: "REFUND_REQUESTED",
      by: req.user?.role || "ADMIN",
      at: new Date(),
      meta: {
        amount: refundAmount,
        stripeRefundId: refund.id,
      },
    });

    await payment.save();

    res.json({
      message: "Refund initiated",
      refund,
    });
  } catch (err) {
    console.error("refundPayment error", err);
    res.status(500).json({ error: err.message });
  }
}


export async function capturePayment(req, res) {
  try {
    const { paymentId } = req.body;

    if (!paymentId) {
      return res.status(400).json({ error: "paymentId is required" });
    }

    const payment = await Payment.findById(paymentId);
    if (!payment) {
      return res.status(404).json({ error: "Payment not found" });
    }

    if (payment.status !== "AUTHORIZED") {
      return res
        .status(400)
        .json({ error: "Only AUTHORIZED payments can be captured" });
    }

    // 🔥 Stripe Capture
    const intent = await stripe.paymentIntents.capture(payment.txnId);

    // نحدّث الحالة في DB
    payment.status = "CAPTURED";
    payment.timeline.push({
      action: "CAPTURED",
      by: req.user?.role || "SYSTEM",
      at: new Date(),
      meta: { stripePaymentIntent: intent.id },
    });
    await payment.save();

    return res.json({ message: "Payment captured", payment });
  } catch (err) {
    console.error("capturePayment error", err);
    res.status(500).json({ error: err.message });
  }
}

export async function cancelPayment(req, res) {
  try {
    const { paymentId } = req.body;

    if (!paymentId) {
      return res.status(400).json({ error: "paymentId is required" });
    }

    const payment = await Payment.findById(paymentId);
    if (!payment) {
      return res.status(404).json({ error: "Payment not found" });
    }

    if (payment.status !== "AUTHORIZED") {
      return res
        .status(400)
        .json({ error: "Only AUTHORIZED payments can be canceled" });
    }

    const intent = await stripe.paymentIntents.cancel(payment.txnId);

    payment.status = "CANCELED";
    payment.timeline.push({
      action: "CANCELED",
      by: req.user?.role || "SYSTEM",
      at: new Date(),
      meta: { stripePaymentIntent: intent.id },
    });
    await payment.save();

    return res.json({ message: "Payment canceled", payment });
  } catch (err) {
    console.error("cancelPayment error", err);
    res.status(500).json({ error: err.message });
  }
}





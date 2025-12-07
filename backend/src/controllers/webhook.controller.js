import dotenv from "dotenv";
dotenv.config();

import Stripe from "stripe";
import Payment from "../models/payment.model.js";

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY);

// =====================
// Stripe Webhook Handler
// =====================
export async function handleStripeWebhook(req, res) {
  let event;

  try {
    event = stripe.webhooks.constructEvent(
      req.body,
      req.headers["stripe-signature"],
      process.env.STRIPE_WEBHOOK_SECRET
    );
  } catch (err) {
    console.error("❌ Invalid Stripe signature:", err.message);
    return res.status(400).send(`Webhook Error: ${err.message}`);
  }

  const data = event.data.object;

  // 📌 1) Payment captured
  if (event.type === "payment_intent.succeeded") {
    await Payment.findOneAndUpdate(
      { txnId: data.id },
      {
        status: "CAPTURED",
        $push: {
          timeline: {
            action: "CAPTURED",
            by: "WEBHOOK",
            at: new Date(),
          },
        },
      }
    );

    console.log("💳 Capture confirmed by Stripe");
  }

  // 📌 2) Refund completed — أهم جزء
  if (event.type === "charge.refunded") {
    console.log("💸 Refund webhook received");

    const paymentIntentId = data.payment_intent;

    // ننقذ البيانات بطريقة آمنة
    const refundObj =
      data.refunds?.data && data.refunds.data.length > 0
        ? data.refunds.data[0]
        : null;

    const refundedAmount = refundObj?.amount
      ? refundObj.amount / 100
      : data.amount_refunded
      ? data.amount_refunded / 100
      : 0;

    const payment = await Payment.findOne({ txnId: paymentIntentId });

    if (payment) {
      payment.status = "REFUNDED";
      payment.refundedAmount = refundedAmount;

      payment.timeline.push({
        action: "REFUNDED",
        by: "WEBHOOK",
        at: new Date(),
        meta: {
          refundId: refundObj?.id || "NO_REFUND_ID",
          amount: refundedAmount,
        },
      });

      await payment.save();
    }

    console.log("💸 Refund updated → REFUNDED");
  }

  res.sendStatus(200);
}


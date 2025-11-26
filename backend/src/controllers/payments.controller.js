// src/controllers/payments.controller.js
import Payment from "../models/payment.model.js";

// ======================================================
// 🔹 Helper functions
// ======================================================

// تحديد نوع البطاقة
function detectBrand(cardNumber) {
  const n = (cardNumber || "").replace(/\D/g, "");
  if (/^4\d{12,18}$/.test(n)) return "VISA";
  if (/^(5[1-5]|2[2-7])\d{14}$/.test(n)) return "MASTERCARD";
  if (/^3[47]\d{13}$/.test(n)) return "AMEX";
  return "CARD";
}

// فحص صلاحية الرقم بخوارزمية Luhn
function luhn(card) {
  const digits = (card || "").replace(/\D/g, "").split("").reverse().map(Number);
  let sum = 0;
  for (let i = 0; i < digits.length; i++) {
    let d = digits[i];
    if (i % 2 === 1) {
      d *= 2;
      if (d > 9) d -= 9;
    }
    sum += d;
  }
  return sum % 10 === 0;
}

// إنشاء رقم معاملة فريد
function generateTxnId() {
  return `TXN_${Date.now()}_${Math.random().toString(36).substring(2, 8).toUpperCase()}`;
}

// ======================================================
// 🔹 Controller: Simulated Payment Charge
// ======================================================
/**
 * POST /api/payments/charge
 * Simulate real-world payment process
 * Body: {
 *  amount, currency, cardholderName, cardNumber, expMonth, expYear, cvv,
 *  customer, expert, service, booking
 * }
 */
export async function chargePublic(req, res) {
  try {
    const {
      amount,
      currency = "USD",
      cardholderName,
      cardNumber,
      expMonth,
      expYear,
      cvv,
      customer,
      expert,
      service,
      booking,
    } = req.body || {};

    // 🧾 تحقق من الحقول الأساسية
    if (!amount || !cardholderName || !cardNumber || !expMonth || !expYear || !cvv) {
      return res.status(400).json({ message: "Missing required payment fields" });
    }

    const digits = String(cardNumber).replace(/\D/g, "");
    if (digits.length < 13 || digits.length > 19 || !luhn(digits)) {
      return res.status(400).json({ message: "Invalid card number" });
    }

    // ⚙️ إعداد بيانات البطاقة والمعاملة
    const last4 = digits.slice(-4);
    const brand = detectBrand(digits);
    const expiry = `${expMonth}/${String(expYear).slice(-2)}`;
    const txnId = generateTxnId();

    // 💰 حساب العمولة وصافي الخبير
    const platformFee = +(amount * 0.1).toFixed(2); // 10% عمولة المنصة
    const netToExpert = +(amount - platformFee).toFixed(2);

    // 🟡 أنشئ سجل الدفع بحالة PENDING
    const payment = await Payment.create({
      holderName: cardholderName,
      cardLast4: last4,
      brand,
      expiry,
      amount,
      currency,
      status: "PENDING",
      txnId,
      platformFee,
      netToExpert,
      customer,
      expert,
      service,
      booking,
      timeline: [{ action: "CREATED", by: "SYSTEM", at: new Date() }],
    });

    // 🧠 نحاكي مزود دفع حقيقي (بشكل تجريبي)
    await new Promise((r) => setTimeout(r, 1200)); // تأخير صغير لمحاكاة الاتصال بالبنك

    // 80% احتمالية نجاح العملية
    const success = Math.random() < 0.8;

   if (success) {
  payment.status = "AUTHORIZED";
  payment.timeline.push({
    action: "AUTHORIZED",
    by: "GATEWAY",
    meta: { authCode: "APPROVED" },
    at: new Date(),
  });
  await payment.save();

  return res.status(201).json({
    message: "Payment authorized",
    paymentId: payment._id,
    status: payment.status,
    txnId: payment.txnId,
    netToExpert: payment.netToExpert,
    platformFee: payment.platformFee,
  });
    }
     else {
      payment.status = "FAILED";
      payment.timeline.push({
        action: "FAILED",
        by: "GATEWAY",
        meta: { reason: "Insufficient funds" },
        at: new Date(),
      });
      await payment.save();
      return res.status(402).json({ message: "Payment failed", paymentId: payment._id });
    }
  } catch (err) {
    console.error("❌ chargePublic error", err);
    return res.status(500).json({ message: "Server error", error: err.message });
  }
}

// ======================================================
// 🔹 Controller: Refund (اختياري)
// ======================================================
export async function refundPayment(req, res) {
  try {
    const { id } = req.params;
    const payment = await Payment.findById(id);
    if (!payment) return res.status(404).json({ message: "Payment not found" });

    if (payment.status !== "CAPTURED") {
      return res.status(400).json({ message: "Only captured payments can be refunded" });
    }

    payment.status = "REFUNDED";
    payment.timeline.push({
      action: "REFUNDED",
      by: "ADMIN",
      at: new Date(),
      meta: { reason: req.body.reason || "Manual refund" },
    });
    await payment.save();

    return res.json({ message: "Payment refunded", paymentId: payment._id });
  } catch (err) {
    console.error("refundPayment error", err);
    return res.status(500).json({ message: "Server error", error: err.message });
  }
}

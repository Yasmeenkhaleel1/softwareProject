// src/controllers/payments.controller.js
import Payment from "../models/payment.model.js";

// very light brand detector (optional)
function detectBrand(cardNumber) {
  const n = (cardNumber || "").replace(/\D/g, "");
  if (/^4\d{12,18}$/.test(n)) return "VISA";
  if (/^(5[1-5]|2[2-7])\d{14}$/.test(n)) return "MASTERCARD";
  if (/^3[47]\d{13}$/.test(n)) return "AMEX";
  return "CARD";
}

// simple Luhn check
function luhn(card) {
  const digits = (card || "")
    .replace(/\D/g, "")
    .split("")
    .reverse()
    .map(Number);
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

/**
 * PUBLIC: POST /api/payments/charge
 * Body: { amount, currency, cardholderName, cardNumber, expMonth, expYear, cvv, customer, expert, service }
 * Returns: 201 { paymentId, status, txnId }
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
    } = req.body || {};

    // minimal validation
    if (!amount || !cardholderName || !cardNumber || !expMonth || !expYear || !cvv) {
      return res.status(400).json({ message: "Missing required fields" });
    }

    const digits = String(cardNumber).replace(/\D/g, "");
    if (digits.length < 13 || digits.length > 19 || !luhn(digits)) {
      return res.status(400).json({ message: "Invalid card" });
    }

    // simulate gateway capture success
    const txnId = `TXN_${Date.now()}_${Math.random().toString(36).slice(2, 8).toUpperCase()}`;
    const last4 = digits.slice(-4);
    const brand = detectBrand(digits);
    const expiry = `${expMonth}/${String(expYear).slice(-2)}`;

    // create mock payment record
    const doc = await Payment.create({
      holderName: cardholderName,
      cardLast4: last4,
      brand,
      expiry,
      amount,
      currency,
      status: "CAPTURED",
      txnId,
      customer,
      expert,
      service,
      createdAt: new Date(),
    });

    return res.status(201).json({
      message: "Payment successful",
      paymentId: doc._id,
      status: doc.status,
      txnId: doc.txnId,
    });
  } catch (err) {
    console.error("chargePublic error", err);
    return res.status(500).json({ message: "Server error", error: err.message });
  }
}

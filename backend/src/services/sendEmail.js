import nodemailer from "nodemailer";

export async function sendEmail(toEmail, otpCode) { 
  try {
    const transporter = nodemailer.createTransport({
      service: "gmail",
      auth: {
        user: process.env.EMAILSENDER,
        pass: process.env.PASSWORDSENDER,
      },
    });

    const info = await transporter.sendMail({
      from: `LostTreasures <${process.env.EMAILSENDER}>`,
      to: toEmail,
      subject: "Verify Your Account - Lost Treasures", 
      html: `
        <h2>Welcome to Lost Treasures!</h2>
        <p>Your 6-digit verification code is:</p>
        <h1 style="color:#d63384; letter-spacing: 2px;">${otpCode}</h1> 
        <p>This code will expire in 10 minutes.</p>
      `,
    });

    console.log("✅ Email sent successfully to:", toEmail);
    return info;
  } catch (error) {
    console.error("❌ Failed to send email:", error.message);
    throw error;
  }
}
// src/controllers/chatbot.controller.js
import dotenv from "dotenv";
dotenv.config();

export const handleChatbotMessage = async (req, res) => {
  try {
    const { message, history, userId } = req.body;

    if (!message || typeof message !== "string") {
      return res.status(400).json({ message: "message is required" });
    }

    // نبني المحادثة اللي بنبعتها لـ OpenAI
    const messages = [
      {
        role: "system",
        content:
          "You are a helpful assistant inside a mentorship platform called Lost Treasures. " +
          "You answer questions about how to use the platform: booking sessions, viewing experts, managing profile, etc. " +
          "You do NOT actually perform actions; you only explain and guide step by step.",
      },
      ...(Array.isArray(history) ? history : []),
      { role: "user", content: message },
    ];

    const openaiRes = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${process.env.OPENAI_API_KEY}`,
      },
      body: JSON.stringify({
        model: "gpt-4o-mini", // أو أي موديل متاح عندك
        messages,
        temperature: 0.4,
      }),
    });

    if (!openaiRes.ok) {
      const errTxt = await openaiRes.text();
      console.error("OpenAI error:", errTxt);
      return res.status(500).json({ message: "LLM error", error: errTxt });
    }

    const data = await openaiRes.json();
    const reply = data.choices?.[0]?.message?.content ?? "Sorry, I have no answer.";

    return res.json({ reply });
  } catch (err) {
    console.error("Chatbot controller error:", err);
    return res
      .status(500)
      .json({ message: "Server error", error: err.message });
  }
};

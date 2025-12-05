export const reply = async (req, res) => {
      console.log("CHATBOT REQUEST:", req.body); 
  try {

    const { message } = req.body;
    if (!message) {
      return res.json({ reply: "No message received." });
    }

    const msg = message.toLowerCase();

    if (msg.includes("book") || msg.includes("service")) {
      return res.json({
        reply: "To book a service, go to the expert profile → click Book Now."
      });
    }

    if (msg.includes("contact") || msg.includes("expert")) {
      return res.json({
        reply: "To contact an expert, open their profile and press Message."
      });
    }

    if (msg.includes("payment") || msg.includes("pay")) {
      return res.json({
        reply: "We support PayPal, Visa, Mastercard and more."
      });
    }

    if (msg.includes("edit") && msg.includes("profile")) {
      return res.json({
        reply: "To edit your profile, go to Account → Edit Profile."
      });
    }

    return res.json({
      reply: "I'm not sure, can you rephrase?"
    });

  } catch (err) {
    console.error(err);
    res.status(500).json({ reply: "Server error occurred." });
  }
};

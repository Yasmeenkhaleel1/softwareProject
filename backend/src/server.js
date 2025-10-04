import express from 'express';
import initAPP from './app.js';
import userModel from './models/user/user.model.js';

const app = express();
const port = process.env.PORT || 4000;

// تهيئة التطبيق (اتصال DB + Routes)
initAPP(app);

// مثال على Endpoint بسيط لجلب المستخدمين
app.get('/users', async (req, res) => {
  try {
    const users = await userModel.find();
    res.json({ message: "success", users });
  } catch (error) {
    console.error("Error fetching users:", error);
    res.status(500).json({ message: "Internal Server Error" });
  }
});

app.listen(port, () => console.log(`🚀 Server running on port ${port}`));

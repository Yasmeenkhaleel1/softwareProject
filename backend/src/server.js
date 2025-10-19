// src/server.js
import express from 'express';
import dotenv from 'dotenv';
import initAPP from './app.js';  // ✅ نستدعي التطبيق الجاهز

dotenv.config();

const app = express();
initAPP(app);  // ✅ نحضّر التطبيق (جميع الإعدادات والمسارات)

const PORT = process.env.PORT || 5000;

app.listen(PORT, () => {
  console.log(`🚀 Server running on http://localhost:${PORT}`);
});

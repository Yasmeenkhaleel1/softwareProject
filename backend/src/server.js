import express from 'express';
import initAPP from './app.js';
import userRouter from './routes/user.routes.js';

const app = express();
const port = process.env.PORT || 5000;

initAPP(app);

app.use('/api', userRouter);

app.listen(port, () => console.log(`🚀 Server running on port ${port}`));

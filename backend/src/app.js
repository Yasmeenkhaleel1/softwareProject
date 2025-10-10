import cors from 'cors';
import mongoose from 'mongoose';
import express from 'express';

const initAPP = (app) => {
  app.use(express.json());
  app.use(cors());

  mongoose.connect('mongodb://localhost:27017/softDB', {
    useNewUrlParser: true,
    useUnifiedTopology: true,
  })
  .then(() => console.log('✅ DB connection established'))
  .catch(err => console.log('❌ DB connection error:', err));
};

export default initAPP;

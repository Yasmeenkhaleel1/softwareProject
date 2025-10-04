import express from 'express';
import initAPP from './models/initApp.js';
import userModel from './models/user/user.model.js';

const app = express();
const port = 3000;
initAPP(app);

app.get('/users', async(req, res) =>{
  const user=await userModel.find();
  return res.json({message:"sucess",user});
});

app.listen(port, () => console.log(`Example app listening on port ${port}!`));


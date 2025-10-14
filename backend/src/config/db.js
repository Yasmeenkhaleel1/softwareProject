import mongoose from "mongoose"; 

const connectDB = async()=>{
  return mongoose.connect('mongodb://127.0.0.1:27017/softDB').then(result=>{
    console.log('DB connection established');
  }).catch(err=>{
    console.log(`error to coonnect db${err}`);
  })
 
}
export default connectDB
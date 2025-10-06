import { Schema , model} from 'mongoose';


const userSchema = new Schema({
  name: {
    type: String,
    required: true,
    trim: true
  },
  email: {
    type: String,
    required: true,
    unique: true,
    lowercase: true
  },
  password: {
    type: String,
    required: true,
    minlength: 6
  },
  age: {
    type: Number,
    min: 1,
    max: 120
  },

  gender: {
    type: String,
    enum: ["male", "female", "other"],
    required: true

  },
  role: {
    type: String,
    enum: ["student", "service_center", "admin"],
    default: "student"
  },
  createdAt: {
    type: Date,
    default: Date.now
  }
});
const userModel=model('User',userSchema);
export default userModel 
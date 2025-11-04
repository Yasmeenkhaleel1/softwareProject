// src/models/availability.model.js
import mongoose from "mongoose";
const WeeklyRuleSchema = new mongoose.Schema(
{
// 0=Sun .. 6=Sat
dow: { type: Number, min: 0, max: 6, required: true },
start: { type: String, required: true }, // "09:00"
end: { type: String, required: true }, // "17:00"
},
{ _id: false }
);
const ExceptionSchema = new mongoose.Schema(
{
date: { type: String, required: true }, // "2025-10-27"
off: { type: Boolean, default: false },
windows: [{ start: String, end: String }],
},
{ _id: false }
);
const AvailabilitySchema = new mongoose.Schema(
{
expert: { type: mongoose.Types.ObjectId, ref: "ExpertProfile", unique: true },
bufferMinutes: { type: Number, default: 10 },
rules: [WeeklyRuleSchema],
exceptions: [ExceptionSchema],
},
{ timestamps: true }
);
export default mongoose.model("availabilities", AvailabilitySchema);
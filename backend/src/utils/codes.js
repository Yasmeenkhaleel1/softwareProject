// src/utils/codes.js
 export function nextBookingCode(date = new Date()) {
const y = date.getUTCFullYear();
const rand = Math.floor(Math.random() * 1_000_000).toString().padStart(6,
"0");
return `BK-${y}-${rand}`;
}
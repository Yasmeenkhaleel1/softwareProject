// src/utils/time.js
import { DateTime } from "luxon"; // npm i luxon
export function toUtc(dateIso, tz) {
return DateTime.fromISO(dateIso, { zone: tz || "UTC" }).toUTC().toJSDate();
}
export function toLocal(dateObj, tz) {
return DateTime.fromJSDate(dateObj, { zone: "UTC" }).setZone(tz ||
"UTC").toISO();
}
export function isBeforeHours(nowUtc, targetUtc, hours) {
const diff = (targetUtc.getTime() - nowUtc.getTime()) / (1000 * 60 * 60);
return diff >= hours;
}
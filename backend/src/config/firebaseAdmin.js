import admin from "firebase-admin";
import { dirname } from "path";
import { fileURLToPath } from "url";
import fs from "fs";

const __dirname = dirname(fileURLToPath(import.meta.url));

// قراءة ملف JSON
const serviceAccount = JSON.parse(
  fs.readFileSync(`${__dirname}/serviceAccountKey.json`, "utf8")
);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

export default admin;

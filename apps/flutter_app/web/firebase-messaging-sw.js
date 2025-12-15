importScripts("https://www.gstatic.com/firebasejs/9.6.11/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/9.6.11/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyAHNnqtcTjMrDCCQvYaKq5V57iI31h1ptk",
  appId: "1:515087594310:web:28255aca1bc92e3d8bab47",
  messagingSenderId: "515087594310",
  projectId: "lost-treasures-d4a3c",
  authDomain: "lost-treasures-d4a3c.firebaseapp.com",
  storageBucket: "lost-treasures-d4a3c.firebasestorage.app",
});

const messaging = firebase.messaging();

// ✅ Background Notifications (when tab is closed / in background)
messaging.onBackgroundMessage((payload) => {
  console.log("[firebase-messaging-sw.js] BG message:", payload);

  const title =
    payload.notification?.title ||
    payload.data?.title ||
    "Lost Treasures";

  const body =
    payload.notification?.body ||
    payload.data?.body ||
    "";

  const data = payload.data || {};

  self.registration.showNotification(title, {
    body,
    icon: "/icons/Icon-192.png",
    data, // مهم عشان click
  });
});

self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  const link = event.notification.data?.link || "/";

  event.waitUntil(
    clients.matchAll({ type: "window", includeUncontrolled: true }).then((clientList) => {
      for (const client of clientList) {
        if (client.url.includes(link) && "focus" in client) return client.focus();
      }
      if (clients.openWindow) return clients.openWindow(link);
    })
  );
});

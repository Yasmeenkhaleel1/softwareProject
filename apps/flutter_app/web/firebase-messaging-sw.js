importScripts("https://www.gstatic.com/firebasejs/9.6.11/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/9.6.11/firebase-messaging-compat.js");

// ⭐ مهم جداً
self.addEventListener("install", event => {
  self.skipWaiting();
});

self.addEventListener("activate", event => {
  event.waitUntil(self.clients.claim());
});

firebase.initializeApp({
 apiKey: 'AIzaSyAHNnqtcTjMrDCCQvYaKq5V57iI31h1ptk',
    appId: '1:515087594310:web:28255aca1bc92e3d8bab47',
    messagingSenderId: '515087594310',
    projectId: 'lost-treasures-d4a3c',  
    authDomain: 'lost-treasures-d4a3c.firebaseapp.com',
    storageBucket: 'lost-treasures-d4a3c.firebasestorage.app'
});

const messaging = firebase.messaging();

// ⭐ Background Notifications (works when app is CLOSED)
messaging.onBackgroundMessage((payload) => {
  console.log("[SW] Background message ", payload);

  self.registration.showNotification(payload.notification.title, {
    body: payload.notification.body,
    icon: "/icons/Icon-192.png"
  });
});

// ⭐ Foreground Web Push Notification (most important)
self.addEventListener("push", function(event) {
  console.log("[SW] Push event received:", event);

  if (!event.data) {
    console.log("[SW] No data in push event");
    return;
  }

  const payload = event.data.json();

  const title = payload.notification?.title || "New Notification";
  const body = payload.notification?.body || "";
  const icon = "/icons/Icon-192.png";

  event.waitUntil(
    self.registration.showNotification(title, {
      body: body,
      icon: icon,
      vibrate: [200, 100, 200],
      data: payload.data || {}
    })
  );
});

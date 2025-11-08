/** Public endpoints that must bypass role checks as well */
const PUBLIC_PATHS = [
  // GET /api/experts/:expertId/availability/slots
  /^\/(?:api\/)?experts\/[^/]+\/availability\/slots\b/i,

  // POST /api/bookings  (الحجز من العميل)
  /^\/(?:api\/)?bookings\b/i,

  // ✅ NEW: POST /api/payments/charge  (الدفع من العميل)
  /^\/(?:api\/)?payments\/charge\b/i,
];

export const requireRole = (...allowed) => {
  return (req, res, next) => {
    try {
      const url = req.originalUrl || req.url || req.path || "";

      // ⛳ بypass للمسارات العامة
      if (PUBLIC_PATHS.some((rx) => rx.test(url))) {
        return next();
      }

      if (!req.user || !req.user.role) {
        return res
          .status(403)
          .json({ message: "Forbidden: insufficient permissions" });
      }

      if (allowed.length && !allowed.includes(req.user.role)) {
        return res
          .status(403)
          .json({ message: "Forbidden: insufficient permissions" });
      }

      return next();
    } catch {
      return res.status(403).json({ message: "Forbidden" });
    }
  };
};

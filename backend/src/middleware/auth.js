// src/middleware/auth.js
import jwt from "jsonwebtoken";

/** Public endpoints that must bypass auth completely */
const PUBLIC_PATHS = [
  // GET /api/experts/:expertId/availability/slots
  /^\/(?:api\/)?experts\/[^/]+\/availability\/slots\b/i,
  // If you also made bookings public, keep this:
  /^\/(?:api\/)?bookings\b/i,
];

export const auth = (requiredRoles) => (req, res, next) => {
  try {
    // Use originalUrl so it still includes /api when mounted
    const url = req.originalUrl || req.url || req.path || "";
    if (PUBLIC_PATHS.some((rx) => rx.test(url))) {
      return next();
    }

    const secret = process.env.JWT_SECRET;
    if (!secret) return res.status(500).json({ message: "Server misconfigured: missing JWT_SECRET" });

    const header = req.headers.authorization || "";
    const [scheme, token] = header.split(" ");
    if (!scheme || !token || scheme.toLowerCase() !== "bearer") {
      return res.status(401).json({ message: "No token" });
    }

    const payload = jwt.verify(token, secret);
    const { id, email, role } = payload || {};
    if (!id || !role) return res.status(401).json({ message: "Invalid token payload" });

    req.user = { id, email, role };

    if (requiredRoles) {
      const list = Array.isArray(requiredRoles) ? requiredRoles : [requiredRoles];
      if (!list.includes(role)) return res.status(403).json({ message: "Forbidden" });
    }

    next();
  } catch {
    return res.status(401).json({ message: "Invalid or expired token" });
  }
};

// middleware/requireRole.js
export const requireRole = (...allowed) => {
  return (req, res, next) => {
    try {
      if (!req.user || !allowed.includes(req.user.role)) {
        return res.status(403).json({ message: "Forbidden: insufficient permissions" });
      }
      next();
    } catch (e) {
      return res.status(403).json({ message: "Forbidden" });
    }
  };
};

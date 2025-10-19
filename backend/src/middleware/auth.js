import jwt from 'jsonwebtoken';

/**
 * auth(requiredRoles)
 * - requiredRoles: string | string[] | undefined
 *   - إذا تُركت فارغة ⇒ أي مستخدم مُسجّل مقبول.
 *   - إذا كانت سلسلة ⇒ دور واحد مطلوب.
 *   - إذا كانت مصفوفة ⇒ أي دور ضمنها مقبول.
 */
export const auth = (requiredRoles) => (req, res, next) => {
  try {
    // 1) تأكد من وجود secret
    if (!process.env.JWT_SECRET) {
      return res.status(500).json({ message: 'Server misconfigured: missing JWT_SECRET' });
    }

    // 2) قراءة التوكن من الهيدر
    const header = req.headers.authorization || '';
    const [scheme, token] = header.split(' ');

    if (!scheme || !token || scheme.toLowerCase() !== 'bearer') {
      return res.status(401).json({ message: 'No token' });
    }

    // 3) تحقق JWT
    const payload = jwt.verify(token, process.env.JWT_SECRET);
    // نتوقع أنك عند الإصدار تعمل: { id, email, role }
    const { id, email, role } = payload || {};
    if (!id || !role) {
      return res.status(401).json({ message: 'Invalid token payload' });
    }

    // ثبّت هوية المستخدم للراوترات اللاحقة
    req.user = { id, email, role };

    // 4) التحقق من الأدوار إن طُلبت
    if (requiredRoles) {
      const rolesArray = Array.isArray(requiredRoles) ? requiredRoles : [requiredRoles];
      if (!rolesArray.includes(role)) {
        return res.status(403).json({ message: 'Forbidden' });
      }
    }

    return next();
  } catch (e) {
    // ممكن تكون Expired أو Invalid
    return res.status(401).json({ message: 'Invalid or expired token' });
  }
};

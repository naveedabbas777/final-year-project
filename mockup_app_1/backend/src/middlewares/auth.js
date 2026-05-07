import { admin } from '../config/firebaseAdmin.js';

const isProduction = (process.env.NODE_ENV || '').toLowerCase() === 'production';
const allowDevAuthFallback =
  (process.env.ALLOW_DEV_AUTH_FALLBACK || '').toLowerCase() === 'true';

// SECURITY: Fail startup if dev auth fallback is enabled in production
if (isProduction && allowDevAuthFallback) {
  throw new Error(
    'SECURITY ERROR: ALLOW_DEV_AUTH_FALLBACK cannot be true in production. ' +
      'Remove or set to "false" to continue.'
  );
}

function buildDevUser(token) {
  // SECURITY: Only allow in non-production environments
  if (isProduction) {
    return null;
  }

  const parts = token.split('.');
  if (parts.length === 3) {
    try {
      const decoded = JSON.parse(Buffer.from(parts[1], 'base64').toString());
      return {
        uid: decoded.uid || decoded.user_id || 'dev-user-123',
        email: decoded.email || 'dev@example.com',
        phoneNumber: decoded.phone || null,
        name: decoded.name || 'Dev User',
      };
    } catch (_error) {
      // Fall through to the default mock user.
    }
  }

  return {
    uid: 'dev-user-123',
    email: 'dev@example.com',
    phoneNumber: null,
    name: 'Dev User',
  };
}

export async function requireAuth(req, res, next) {
  try {
    const authHeader = req.headers.authorization || '';
    const [, token] = authHeader.split(' ');

    if (!token) {
      res.status(401).json({ message: 'Missing bearer token' });
      return;
    }

    try {
      const decoded = await admin.auth().verifyIdToken(token, true);
      req.user = {
        uid: decoded.uid,
        email: decoded.email || null,
        phoneNumber: decoded.phone_number || null,
        name: decoded.name || null,
      };
    } catch (firebaseError) {
      if (!allowDevAuthFallback) {
        console.warn('[Auth] Firebase token verification failed:', firebaseError.message);
        res.status(401).json({ message: 'Invalid or expired auth token' });
        return;
      }

      console.warn(
        '[Auth] Using dev auth fallback because ALLOW_DEV_AUTH_FALLBACK=true. ' +
          'This should NEVER be used in production.'
      );
      req.user = buildDevUser(token);
      if (!req.user) {
        res.status(401).json({ message: 'Dev auth fallback failed' });
        return;
      }
    }

    next();
  } catch (_err) {
    console.error('[Auth] Auth middleware error:', _err.message);
    res.status(401).json({ message: 'Invalid or expired auth token' });
  }
}

export function requireRole(...roles) {
  return (req, res, next) => {
    const role = req.dbUser?.role || 'farmer';
    if (!roles.includes(role)) {
      res.status(403).json({ message: 'Forbidden' });
      return;
    }
    next();
  };
}

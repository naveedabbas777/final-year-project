import { admin } from '../config/firebaseAdmin.js';

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
      // Firebase not initialized (no service account key)
      // In development, create a mock user from the token
      // In production, this should fail
      console.warn('[Auth] Firebase token verification failed, using mock auth for development');
      
      // For development: extract basic info from token if it's a valid JWT
      const parts = token.split('.');
      if (parts.length === 3) {
        try {
          const decoded = JSON.parse(Buffer.from(parts[1], 'base64').toString());
          req.user = {
            uid: decoded.uid || decoded.user_id || 'dev-user-123',
            email: decoded.email || 'dev@example.com',
            phoneNumber: decoded.phone || null,
            name: decoded.name || 'Dev User',
          };
        } catch (e) {
          // If we can't parse, use a default dev user
          req.user = {
            uid: 'dev-user-123',
            email: 'dev@example.com',
            phoneNumber: null,
            name: 'Dev User',
          };
        }
      } else {
        // Not a valid JWT format, use default dev user
        req.user = {
          uid: 'dev-user-123',
          email: 'dev@example.com',
          phoneNumber: null,
          name: 'Dev User',
        };
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

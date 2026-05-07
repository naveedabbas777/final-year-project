import { admin } from '../config/firebaseAdmin.js';

/**
 * Collect all FCM tokens from a user document's data.
 * Handles both `fcmTokens` (array) and legacy `fcmToken` (string).
 */
function collectFcmTokens(userData) {
  const tokens = [];
  if (Array.isArray(userData?.fcmTokens)) {
    tokens.push(...userData.fcmTokens.filter(Boolean));
  }
  if (typeof userData?.fcmToken === 'string' && userData.fcmToken.trim()) {
    tokens.push(userData.fcmToken.trim());
  }
  return [...new Set(tokens)];
}

/**
 * Remove invalid/expired FCM tokens from a user document.
 */
async function removeInvalidTokens(userId, invalidTokens) {
  if (!userId || invalidTokens.length === 0) return;
  try {
    await admin.firestore().collection('users').doc(userId).set(
      { fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens) },
      { merge: true },
    );
  } catch (err) {
    console.error(`[FCM] Failed to remove invalid tokens for ${userId}:`, err.message);
  }
}

/**
 * Send a push notification to a single user by UID.
 * Looks up their FCM tokens, sends multicast, prunes invalid tokens.
 *
 * @param {string} uid - Firebase UID of the target user
 * @param {string} title - Notification title
 * @param {string} body - Notification body text
 * @param {Record<string, string>} [data] - Optional data payload (all values must be strings)
 * @returns {Promise<{sent: number, failed: number}>}
 */
export async function sendPushToUser(uid, title, body, data = {}) {
  if (!uid) return { sent: 0, failed: 0 };

  try {
    const userSnap = await admin.firestore().collection('users').doc(uid).get();
    const userData = userSnap.exists ? userSnap.data() : null;
    const tokens = collectFcmTokens(userData);
    if (tokens.length === 0) return { sent: 0, failed: 0 };

    // Ensure all data values are strings (FCM requirement)
    const stringData = {};
    for (const [key, value] of Object.entries(data)) {
      stringData[key] = String(value ?? '');
    }

    const resp = await admin.messaging().sendMulticast({
      tokens,
      notification: { title, body },
      data: stringData,
    });

    // Prune invalid tokens
    if (resp.failureCount > 0) {
      const invalidTokens = [];
      resp.responses.forEach((r, i) => {
        if (!r.success) invalidTokens.push(tokens[i]);
      });
      await removeInvalidTokens(uid, invalidTokens);
    }

    return { sent: resp.successCount, failed: resp.failureCount };
  } catch (err) {
    console.error(`[FCM] Error sending push to user ${uid}:`, err.message);
    return { sent: 0, failed: 0 };
  }
}

/**
 * Send a push notification to all users with `role === 'admin'`.
 *
 * @param {string} title
 * @param {string} body
 * @param {Record<string, string>} [data]
 * @returns {Promise<{sent: number, failed: number}>}
 */
export async function sendPushToAdmins(title, body, data = {}) {
  return sendPushToRole('admin', title, body, data);
}

/**
 * Send a push notification to all users with a specific role.
 *
 * @param {string} role - e.g. 'admin', 'farmer', 'buyer'
 * @param {string} title
 * @param {string} body
 * @param {Record<string, string>} [data]
 * @returns {Promise<{sent: number, failed: number}>}
 */
export async function sendPushToRole(role, title, body, data = {}) {
  try {
    const usersSnap = await admin.firestore().collection('users')
      .where('role', '==', role)
      .get();

    let totalSent = 0;
    let totalFailed = 0;

    for (const doc of usersSnap.docs) {
      const uid = doc.data()?.firebaseUid || doc.id;
      const result = await sendPushToUser(uid, title, body, data);
      totalSent += result.sent;
      totalFailed += result.failed;
    }

    return { sent: totalSent, failed: totalFailed };
  } catch (err) {
    console.error(`[FCM] Error sending push to role ${role}:`, err.message);
    return { sent: 0, failed: 0 };
  }
}

/**
 * Send push notifications to a list of user UIDs.
 *
 * @param {string[]} uids
 * @param {string} title
 * @param {string} body
 * @param {Record<string, string>} [data]
 * @returns {Promise<{sent: number, failed: number}>}
 */
export async function sendPushToUsers(uids, title, body, data = {}) {
  let totalSent = 0;
  let totalFailed = 0;

  for (const uid of uids) {
    const result = await sendPushToUser(uid, title, body, data);
    totalSent += result.sent;
    totalFailed += result.failed;
  }

  return { sent: totalSent, failed: totalFailed };
}

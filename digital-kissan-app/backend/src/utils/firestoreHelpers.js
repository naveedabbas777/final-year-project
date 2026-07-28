import { admin } from '../config/firebaseAdmin.js';

/**
 * Convert a Firestore Timestamp (or Date-like value) to an ISO string.
 */
export function toIso(value) {
  if (!value) return null;
  if (typeof value.toDate === 'function') return value.toDate().toISOString();
  const d = new Date(value);
  return Number.isNaN(d.getTime()) ? null : d.toISOString();
}

/**
 * Convert a Firestore DocumentSnapshot to a plain JSON object.
 * Includes `id` (the document ID) and serialises Timestamp fields.
 */
export function docToJson(doc) {
  if (!doc || !doc.exists) return null;
  const data = doc.data();
  return {
    id: doc.id,
    _id: doc.id, // keep _id for backward compat with frontend
    ...data,
    createdAt: toIso(data.createdAt),
    updatedAt: toIso(data.updatedAt),
  };
}

/**
 * Convert a QuerySnapshot to an array of plain JSON objects.
 */
export function queryToJson(snapshot) {
  return snapshot.docs.map((d) => docToJson(d)).filter(Boolean);
}

/**
 * Shorthand for Firestore server timestamp.
 */
export function serverTimestamp() {
  return admin.firestore.FieldValue.serverTimestamp();
}

/**
 * Get a reference to a Firestore collection.
 */
export function col(name) {
  return admin.firestore().collection(name);
}

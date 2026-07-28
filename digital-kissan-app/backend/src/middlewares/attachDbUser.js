import { admin } from '../config/firebaseAdmin.js';

export async function attachDbUser(req, _res, next) {
  if (!req.user?.uid) {
    next();
    return;
  }

  try {
    const firestore = admin.firestore();
    const docRef = firestore.collection('users').doc(req.user.uid);
    const snap = await docRef.get();

    let userData;
    if (!snap.exists) {
      const initial = {
        firebaseUid: req.user.uid,
        phone: req.user.phoneNumber || null,
        phoneNumber: req.user.phoneNumber || null,
        name: req.user.name || null,
        displayName: req.user.name || null,
        role: 'farmer',
        district: null,
        province: null,
        address: null,
        lat: null,
        lon: null,
        locationUpdatedAt: null,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      };
      await docRef.set(initial);
      userData = { id: docRef.id, ...initial };
    } else {
      userData = { id: docRef.id, ...snap.data() };
    }

    userData.save = async function save() {
      const toSave = { ...userData };
      delete toSave.id;
      delete toSave.save;
      if (toSave.name != null && toSave.displayName == null) toSave.displayName = toSave.name;
      if (toSave.displayName != null && toSave.name == null) toSave.name = toSave.displayName;
      if (toSave.phone != null && toSave.phoneNumber == null) toSave.phoneNumber = toSave.phone;
      if (toSave.phoneNumber != null && toSave.phone == null) toSave.phone = toSave.phoneNumber;
      await docRef.set(toSave, { merge: true });
      return this;
    };

    req.dbUser = userData;
    next();
  } catch (error) {
    next(error);
  }
}

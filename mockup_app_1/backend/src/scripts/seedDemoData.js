import { initFirebaseAdmin } from '../config/firebaseAdmin.js';
import { admin } from '../config/firebaseAdmin.js';

async function seed() {
  initFirebaseAdmin();
  const firestore = admin.firestore();
  const now = new Date();

  const rates = [
    {
      cropName: 'Wheat',
      marketName: 'Lahore Mandi',
      district: 'Lahore',
      minPrice: 3050,
      maxPrice: 3240,
      unit: '40kg',
      sourceName: 'Punjab Agriculture Dept (demo)',
      sourceUrl: 'https://agripunjab.gov.pk/',
      isOfficialSource: true,
      rateDate: now,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {
      cropName: 'Rice',
      marketName: 'Multan Grain Market',
      district: 'Multan',
      minPrice: 4900,
      maxPrice: 5300,
      unit: '40kg',
      sourceName: 'Punjab Agriculture Dept (demo)',
      sourceUrl: 'https://agripunjab.gov.pk/',
      isOfficialSource: true,
      rateDate: now,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {
      cropName: 'Maize',
      marketName: 'Faisalabad Mandi',
      district: 'Faisalabad',
      minPrice: 2400,
      maxPrice: 2660,
      unit: '40kg',
      sourceName: 'PARC (demo)',
      sourceUrl: 'https://www.parc.gov.pk/',
      isOfficialSource: true,
      rateDate: now,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
  ];

  const listings = [
    {
      sellerUid: 'demo-seller-001',
      cropName: 'Wheat',
      qualityGrade: 'A',
      quantity: 120,
      unit: '40kg',
      askingPrice: 3200,
      district: 'Lahore',
      description: 'Dry grain, ready for pickup.',
      imageUrls: [],
      status: 'open',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {
      sellerUid: 'demo-seller-002',
      cropName: 'Rice',
      qualityGrade: 'A+',
      quantity: 80,
      unit: '40kg',
      askingPrice: 5250,
      district: 'Multan',
      description: 'Premium batch, recently harvested.',
      imageUrls: [],
      status: 'open',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
  ];

  // Delete old demo data
  const oldRatesSnap = await firestore.collection('crop_rates').where('sourceName', '>=', 'P').where('sourceName', '<=', 'P\uf8ff').get();
  const oldListingsSnap = await firestore.collection('listings').where('sellerUid', '>=', 'demo-seller-').where('sellerUid', '<=', 'demo-seller-\uf8ff').get();

  const batch = firestore.batch();
  oldRatesSnap.docs.forEach((doc) => {
    if (doc.data().sourceName?.includes('(demo)')) batch.delete(doc.ref);
  });
  oldListingsSnap.docs.forEach((doc) => batch.delete(doc.ref));
  await batch.commit();

  // Insert new demo data
  const insertBatch = firestore.batch();
  for (const rate of rates) {
    insertBatch.set(firestore.collection('crop_rates').doc(), rate);
  }
  for (const listing of listings) {
    insertBatch.set(firestore.collection('listings').doc(), listing);
  }
  await insertBatch.commit();

  // eslint-disable-next-line no-console
  console.log(
    `Seed complete: ${rates.length} rates, ${listings.length} listings.`,
  );

  process.exit(0);
}

seed().catch((err) => {
  // eslint-disable-next-line no-console
  console.error('Seed failed', err);
  process.exit(1);
});

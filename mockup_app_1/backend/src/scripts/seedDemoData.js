import { connectDb } from '../config/db.js';
import { env } from '../config/env.js';
import { CropRateModel } from '../models/cropRate.model.js';
import { ListingModel } from '../models/listing.model.js';

async function seed() {
  await connectDb(env.mongoUri);

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
    },
  ];

  await CropRateModel.deleteMany({ sourceName: { $regex: /\(demo\)$/i } });
  await ListingModel.deleteMany({ sellerUid: { $regex: /^demo-seller-/ } });

  const insertedRates = await CropRateModel.insertMany(rates);
  const insertedListings = await ListingModel.insertMany(listings);

  // eslint-disable-next-line no-console
  console.log(
    `Seed complete: ${insertedRates.length} rates, ${insertedListings.length} listings.`,
  );

  process.exit(0);
}

seed().catch((err) => {
  // eslint-disable-next-line no-console
  console.error('Seed failed', err);
  process.exit(1);
});

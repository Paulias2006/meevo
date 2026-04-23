import 'dotenv/config';
import { connectDatabase } from '../src/config/database.js';
import { User } from '../src/models/User.js';
import { hashPassword } from '../src/utils/auth.js';

function readArg(name) {
  const index = process.argv.findIndex((arg) => arg === `--${name}`);
  if (index === -1) return '';
  return process.argv[index + 1] ?? '';
}

async function run() {
  const email = readArg('email') || process.env.ADMIN_EMAIL || '';
  const password = readArg('password') || process.env.ADMIN_PASSWORD || '';
  const fullNameArg = readArg('name') || process.env.ADMIN_NAME || '';
  const phoneArg = readArg('phone') || process.env.ADMIN_PHONE || '';
  const cityArg = readArg('city') || process.env.ADMIN_CITY || '';

  if (!email || !password) {
    console.error(
      'Usage: node scripts/create-admin.js --email admin@meevo.tg --password MonMotDePasse --name "Admin Meevo"',
    );
    process.exit(1);
  }

  await connectDatabase(process.env.MONGODB_URI);

  const existing = await User.findOne({ email });
  if (existing) {
    existing.role = 'admin';
    if (fullNameArg.trim().length > 0) {
      existing.fullName = fullNameArg;
    }
    if (phoneArg.trim().length > 0) {
      existing.phone = phoneArg;
    }
    if (cityArg.trim().length > 0) {
      existing.city = cityArg;
    }
    existing.passwordHash = await hashPassword(password);
    await existing.save();
    console.log('Admin mis a jour:', email);
    process.exit(0);
  }

  const passwordHash = await hashPassword(password);
  const fullName = fullNameArg.trim().length > 0 ? fullNameArg : 'Admin Meevo';
  const city = cityArg.trim().length > 0 ? cityArg : 'Lome';
  await User.create({
    fullName,
    email,
    phone: phoneArg,
    passwordHash,
    role: 'admin',
    city,
  });

  console.log('Admin cree:', email);
  process.exit(0);
}

run().catch((error) => {
  console.error('Erreur create-admin:', error);
  process.exit(1);
});

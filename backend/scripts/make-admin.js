import 'dotenv/config';
import { connectDatabase } from '../src/config/database.js';
import { User } from '../src/models/User.js';

function readArg(name) {
  const index = process.argv.findIndex((arg) => arg === `--${name}`);
  if (index == -1) return '';
  return process.argv[index + 1] ?? '';
}

async function run() {
  const email = readArg('email') || process.env.ADMIN_EMAIL || '';

  if (!email) {
    console.error(
      'Usage: node scripts/make-admin.js --email togohpaul@gmail.com',
    );
    process.exit(1);
  }

  await connectDatabase(process.env.MONGODB_URI);

  const user = await User.findOne({ email });
  if (!user) {
    console.error('Aucun utilisateur trouve avec cet email:', email);
    process.exit(1);
  }

  user.role = 'admin';
  await user.save();
  console.log('Role admin active pour:', email);
  process.exit(0);
}

run().catch((error) => {
  console.error('Erreur make-admin:', error);
  process.exit(1);
});

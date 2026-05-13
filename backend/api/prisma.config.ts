import 'dotenv/config';
import { defineConfig, env } from 'prisma/config';

export default defineConfig({
  schema: 'prisma/schema.prisma',
  migrations: {
    path: 'prisma/migrations',
  },
  datasource: {
    url: 'mysql://root:secure_password@localhost:3306/challengedb',
    // url: env('DATABASE_URL'),
  },
});

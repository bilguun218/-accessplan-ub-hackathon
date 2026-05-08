import { createApp } from './app';
import { connectDB } from './config/db';
import { env } from './config/env';

async function bootstrap() {
  await connectDB();
  const app = createApp();
  app.listen(env.port, () => {
    console.log(`[server] AccessPlan UB API listening on http://localhost:${env.port}`);
  });
}

bootstrap().catch((err) => {
  console.error('[fatal]', err);
  process.exit(1);
});

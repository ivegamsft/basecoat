import 'dotenv/config';
import { createApp } from './app';
import sequelize from './config/database';
import logger from './config/logger';

const PORT = Number(process.env.PORT) || 3000;

async function main(): Promise<void> {
  try {
    await sequelize.authenticate();
    logger.info('Database connection established');
  } catch (err) {
    logger.warn('Could not connect to database — starting without DB', { error: (err as Error).message });
  }

  const app = createApp();

  app.listen(PORT, () => {
    logger.info(`Server listening on port ${PORT}`);
  });
}

main().catch((err) => {
  console.error('Fatal startup error', err);
  process.exit(1);
});

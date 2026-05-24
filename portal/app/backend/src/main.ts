import 'dotenv/config';
import App from '@config/app';
import logger from '@config/logger';

const app = new App();

// Graceful shutdown
process.on('SIGTERM', async () => {
  logger.info('SIGTERM signal received: closing HTTP server');
  await app.stop();
  process.exit(0);
});

process.on('SIGINT', async () => {
  logger.info('SIGINT signal received: closing HTTP server');
  await app.stop();
  process.exit(0);
});

// Unhandled rejection handler
process.on('unhandledRejection', (reason, promise) => {
  logger.error('Unhandled Rejection at:', {
    promise: String(promise),
    reason: String(reason),
  });
  process.exit(1);
});

// Start server
app.start().catch((error) => {
  logger.error('Fatal error starting application', {
    error: error instanceof Error ? error.message : 'Unknown error',
  });
  process.exit(1);
});

export default app;

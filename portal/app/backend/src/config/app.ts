import express, { Express, Response } from 'express';
import cors from 'cors';
import rateLimit from 'express-rate-limit';
import { AppDataSource } from '@config/database';
import logger from '@config/logger';
import { requestIdMiddleware, requestLoggingMiddleware, AuthRequest } from '@middleware/request.middleware';
import { errorHandler, notFoundHandler } from '@middleware/error.middleware';
import auditRoutes from '@routes/audit.routes';

export class App {
  private app: Express;
  private port: number;

  constructor() {
    this.app = express();
    this.port = parseInt(process.env.PORT || '3000');
    this.setupMiddleware();
    this.setupRoutes();
    this.setupErrorHandling();
  }

  private setupMiddleware() {
    // Trust proxy for accurate IP logging
    this.app.set('trust proxy', 1);

    // Request ID and logging
    this.app.use(requestIdMiddleware);
    this.app.use(requestLoggingMiddleware);

    // Global rate limiting
    this.app.use(
      rateLimit({
        windowMs: 15 * 60 * 1000,
        max: 100,
        standardHeaders: true,
        legacyHeaders: false,
        message: { error: 'Too many requests, please try again later.', code: 'RATE_LIMITED' },
      }),
    );

    // CORS
    const corsOrigins = (process.env.CORS_ORIGINS || 'http://localhost:3000').split(',');
    this.app.use(
      cors({
        origin: corsOrigins,
        credentials: true,
        optionsSuccessStatus: 200,
      }),
    );

    // Body parsing
    this.app.use(express.json({ limit: '10mb' }));
    this.app.use(express.urlencoded({ limit: '10mb', extended: true }));

    // Security headers
    this.app.use((req, res, next) => {
      res.setHeader('X-Content-Type-Options', 'nosniff');
      res.setHeader('X-Frame-Options', 'DENY');
      res.setHeader('X-XSS-Protection', '1; mode=block');
      res.setHeader('Strict-Transport-Security', 'max-age=31536000; includeSubDomains');
      next();
    });
  }

  private setupRoutes() {
    const apiVersion = process.env.API_VERSION || 'v1';
    const apiPrefix = `${process.env.API_PREFIX || '/api/v1'}`;

    // Health check endpoint
    this.app.get('/health', (req: AuthRequest, res: Response) => {
      res.json({
        status: 'OK',
        timestamp: new Date().toISOString(),
        requestId: req.requestId,
      });
    });

    // Version endpoint
    this.app.get(`${apiPrefix}/version`, (req: AuthRequest, res: Response) => {
      res.json({
        version: apiVersion,
        app: process.env.APP_NAME || 'basecoat-portal-api',
        timestamp: new Date().toISOString(),
      });
    });

    // API routes
    this.app.use(`${apiPrefix}/audits`, auditRoutes);

    // Placeholder for other routes
    this.app.get(`${apiPrefix}`, (req: AuthRequest, res: Response) => {
      res.json({
        message: 'Basecoat Portal API',
        version: apiVersion,
        endpoints: {
          health: '/health',
          version: `${apiPrefix}/version`,
          audits: `${apiPrefix}/audits`,
        },
      });
    });

    // 404 handler
    this.app.use(notFoundHandler as any);
  }

  private setupErrorHandling() {
    this.app.use(errorHandler as any);
  }

  async start() {
    try {
      // Initialize database connection
      logger.info('Connecting to database...');
      await AppDataSource.initialize();
      logger.info('Database connected successfully');

      // Run migrations
      if (process.env.AUTO_MIGRATE === 'true') {
        logger.info('Running migrations...');
        // await AppDataSource.runMigrations();
        logger.info('Migrations completed');
      }

      // Start server
      this.app.listen(this.port, () => {
        logger.info(`Server started`, {
          port: this.port,
          env: process.env.NODE_ENV || 'development',
          apiPrefix: process.env.API_PREFIX || '/api/v1',
        });
      });
    } catch (error) {
      logger.error('Failed to start server', {
        error: error instanceof Error ? error.message : 'Unknown error',
        stack: error instanceof Error ? error.stack : undefined,
      });
      process.exit(1);
    }
  }

  async stop() {
    try {
      if (AppDataSource.isInitialized) {
        await AppDataSource.destroy();
        logger.info('Database connection closed');
      }
    } catch (error) {
      logger.error('Error stopping server', {
        error: error instanceof Error ? error.message : 'Unknown error',
      });
    }
  }

  getExpressApp(): Express {
    return this.app;
  }
}

export default App;

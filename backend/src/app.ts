import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import authRoutes from './routes/auth.routes';
import mapsRoutes from './routes/maps.routes';
import aiRoutes from './routes/ai.routes';
import { errorHandler, notFoundHandler } from './middleware/error.middleware';
import { generalLimiter } from './middleware/rateLimit.middleware';

export function createApp() {
  const app = express();

  app.use(helmet());
  app.use(cors());
  app.use(express.json({ limit: '1mb' }));
  app.use(generalLimiter);

  app.get('/health', (_req, res) => {
    res.json({ status: 'ok', service: 'accessplan-ub-backend' });
  });

  app.use('/api/auth', authRoutes);
  app.use('/api/maps', mapsRoutes);
  app.use('/api/ai', aiRoutes);

  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
}

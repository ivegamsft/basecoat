import winston from 'winston';
import path from 'path';

const logsDir = 'logs';

const customFormat = winston.format.combine(
  winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
  winston.format.errors({ stack: true }),
  winston.format.json(),
);

const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: customFormat,
  defaultMeta: { service: process.env.APP_NAME || 'basecoat-api' },
  transports: [
    new winston.transports.File({
      filename: path.join(logsDir, 'error.log'),
      level: 'error',
      maxsize: 10485760, // 10MB
      maxFiles: 30,
    }),
    new winston.transports.File({
      filename: path.join(logsDir, 'app.log'),
      maxsize: 10485760,
      maxFiles: 30,
    }),
  ],
});

if (process.env.NODE_ENV !== 'production') {
  logger.add(
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.colorize(),
        winston.format.printf(({ timestamp, level, message, requestId, ...rest }) => {
          return `${timestamp} [${level}] ${requestId ? `[${requestId}] ` : ''}${message} ${Object.keys(rest).length ? JSON.stringify(rest) : ''}`;
        }),
      ),
    }),
  );
}

export default logger;

import 'dotenv/config';
import { DataSource } from 'typeorm';
import { User } from '@models/user.entity';
import { Team } from '@models/team.entity';
import { Repository } from '@models/repository.entity';
import { Audit } from '@models/audit.entity';
import { Finding } from '@models/finding.entity';

export const AppDataSource = new DataSource({
  type: 'postgres',
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT || '5432'),
  username: process.env.DB_USER || 'postgres',
  password: process.env.DB_PASSWORD || 'postgres',
  database: process.env.DB_NAME || 'basecoat_db',
  synchronize: process.env.NODE_ENV === 'development',
  logging: process.env.NODE_ENV === 'development',
  entities: [User, Team, Repository, Audit, Finding],
  migrations: ['dist/src/migrations/*.js'],
  subscribers: ['dist/src/subscribers/*.js'],
  ssl: process.env.DB_SSL === 'true',
  poolSize: parseInt(process.env.DB_POOL_MAX || '50'),
  maxQueryExecutionTime: 30000,
  cache: {
    type: 'database',
    duration: 60000,
  },
});

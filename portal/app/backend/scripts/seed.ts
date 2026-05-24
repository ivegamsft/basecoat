import 'dotenv/config';
import { AppDataSource } from '@config/database';
import { User, UserRole } from '@models/user.entity';
import { Team } from '@models/team.entity';
import { Repository as RepositoryEntity, ComplianceLevel } from '@models/repository.entity';
import bcrypt from 'bcryptjs';
import logger from '@config/logger';

async function seed() {
  try {
    if (!AppDataSource.isInitialized) {
      await AppDataSource.initialize();
    }

    const userRepository = AppDataSource.getRepository(User);
    const teamRepository = AppDataSource.getRepository(Team);
    const repositoryRepository = AppDataSource.getRepository(RepositoryEntity);

    logger.info('Seeding database...');

    // Create users
    const adminUser = userRepository.create({
      email: 'admin@basecoat.dev',
      name: 'Admin User',
      passwordHash: bcrypt.hashSync('password123', 10),
      role: UserRole.ADMIN,
      emailVerified: true,
    });

    const auditorUser = userRepository.create({
      email: 'auditor@basecoat.dev',
      name: 'Auditor User',
      passwordHash: bcrypt.hashSync('password123', 10),
      role: UserRole.AUDITOR,
      emailVerified: true,
    });

    const developerUser = userRepository.create({
      email: 'developer@basecoat.dev',
      name: 'Developer User',
      passwordHash: bcrypt.hashSync('password123', 10),
      role: UserRole.DEVELOPER,
      emailVerified: true,
    });

    const viewerUser = userRepository.create({
      email: 'viewer@basecoat.dev',
      name: 'Viewer User',
      passwordHash: bcrypt.hashSync('password123', 10),
      role: UserRole.VIEWER,
      emailVerified: true,
    });

    await userRepository.save([adminUser, auditorUser, developerUser, viewerUser]);
    logger.info('Created 4 test users');

    // Create teams
    const team1 = teamRepository.create({
      name: 'Platform Team',
      description: 'Core platform and infrastructure team',
    });

    const team2 = teamRepository.create({
      name: 'Security Team',
      description: 'Security and compliance team',
    });

    await teamRepository.save([team1, team2]);
    logger.info('Created 2 test teams');

    // Create repositories
    const repo1 = repositoryRepository.create({
      name: 'basecoat-core',
      url: 'https://github.com/basecoat/basecoat-core',
      teamId: team1.id,
      isPrivate: false,
      language: 'TypeScript',
      complianceLevel: ComplianceLevel.LEVEL3,
    });

    const repo2 = repositoryRepository.create({
      name: 'basecoat-api',
      url: 'https://github.com/basecoat/basecoat-api',
      teamId: team1.id,
      isPrivate: true,
      language: 'TypeScript',
      complianceLevel: ComplianceLevel.LEVEL4,
    });

    const repo3 = repositoryRepository.create({
      name: 'basecoat-cli',
      url: 'https://github.com/basecoat/basecoat-cli',
      teamId: team2.id,
      isPrivate: false,
      language: 'Go',
      complianceLevel: ComplianceLevel.LEVEL2,
    });

    await repositoryRepository.save([repo1, repo2, repo3]);
    logger.info('Created 3 test repositories');

    logger.info('Database seeding completed successfully');
    process.exit(0);
  } catch (error) {
    logger.error('Seeding failed', {
      error: error instanceof Error ? error.message : 'Unknown error',
      stack: error instanceof Error ? error.stack : undefined,
    });
    process.exit(1);
  }
}

seed();

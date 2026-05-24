import 'dotenv/config';
import { AppDataSource } from '@config/database';

// Setup test database connection
export async function setupTestDatabase() {
  if (!AppDataSource.isInitialized) {
    await AppDataSource.initialize();
  }
}

export async function teardownTestDatabase() {
  if (AppDataSource.isInitialized) {
    await AppDataSource.destroy();
  }
}

export async function clearDatabase() {
  if (AppDataSource.isInitialized) {
    const entities = AppDataSource.entityMetadatas;

    for (const entity of entities) {
      const repository = AppDataSource.getRepository(entity.name);
      await repository.query(`TRUNCATE TABLE "${entity.tableName}" CASCADE;`);
    }
  }
}

// Global setup
beforeAll(async () => {
  await setupTestDatabase();
});

// Global teardown
afterAll(async () => {
  await teardownTestDatabase();
});

// Clear database before each test suite
beforeEach(async () => {
  await clearDatabase();
});

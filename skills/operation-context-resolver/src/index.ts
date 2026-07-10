export { OperationContextResolver } from './resolver';
export { validateEnvironmentMap } from './validator';
export type {
  Environment,
  RiskLevel,
  OperationMode,
  ResolverInput,
  EnvironmentConfig,
  OperationContext,
  EnvironmentMap,
  ResolverRule,
  ValidationResult,
} from './types';

// Convenience function for single-use resolver
export async function resolveOperationContext(
  input: import('./types').ResolverInput,
  repoRoot: string = process.cwd()
): Promise<import('./types').OperationContext> {
  const { OperationContextResolver } = await import('./resolver');
  const resolver = await OperationContextResolver.fromRepoRoot(repoRoot);
  return resolver.resolve(input);
}

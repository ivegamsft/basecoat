export { OperationContextResolver } from './resolver.js';
export { validateEnvironmentMap } from './validator.js';
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
} from './types.js';

// Convenience function for single-use resolver
export async function resolveOperationContext(
  input: import('./types.js').ResolverInput,
  repoRoot: string = process.cwd()
): Promise<import('./types.js').OperationContext> {
  const { OperationContextResolver } = await import('./resolver.js');
  const resolver = await OperationContextResolver.fromRepoRoot(repoRoot);
  return resolver.resolve(input);
}

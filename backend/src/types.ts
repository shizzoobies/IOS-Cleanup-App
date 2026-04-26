export interface Env {
  CACHE: KVNamespace;
  RATE_LIMITS: KVNamespace;
  ANTHROPIC_API_KEY: string;
  HAIKU_MODEL: string;
  SONNET_MODEL: string;
  ENVIRONMENT: string;
}

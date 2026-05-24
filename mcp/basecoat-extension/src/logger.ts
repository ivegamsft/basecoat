type LogLevel = "info" | "warn" | "error";
type LogFields = Record<string, string | number | boolean | null | undefined>;

function write(level: LogLevel, event: string, fields: LogFields = {}) {
  const payload: Record<string, unknown> = {
    timestamp: new Date().toISOString(),
    level,
    service: "basecoat-extension",
    event,
  };

  for (const [key, value] of Object.entries(fields)) {
    if (value !== undefined) {
      payload[key] = value;
    }
  }

  console.log(JSON.stringify(payload));
}

export const logger = {
  info: (event: string, fields?: LogFields) => write("info", event, fields),
  warn: (event: string, fields?: LogFields) => write("warn", event, fields),
  error: (event: string, fields?: LogFields) => write("error", event, fields),
};


import { CopilotClient } from "@github/copilot-sdk";

export type CopilotPingResult = {
  message: string;
  timestamp: number;
};

export class CopilotRuntime {
  private client: CopilotClient | null = null;

  private async getClient(): Promise<CopilotClient> {
    if (!this.client) {
      this.client = new CopilotClient();
      await this.client.start();
    }

    return this.client;
  }

  async ping(): Promise<CopilotPingResult> {
    const client = await this.getClient();
    return client.ping("basecoat-extension");
  }

  async stop(): Promise<void> {
    if (!this.client) {
      return;
    }

    await this.client.stop();
    this.client = null;
  }
}

export const copilotRuntime = new CopilotRuntime();

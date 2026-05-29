/** Registers compatibility help for the legacy clawbot command name. */
import type { Command } from "commander";
import { formatDocsLink } from "../terminal/links.js";
import { theme } from "../terminal/theme.js";
import { registerQrCli } from "./qr-cli.js";

/** Reused helper for register Clawbot Cli behavior in src/cli. */
export function registerClawbotCli(program: Command) {
  const clawbot = program
    .command("clawbot")
    .description("Legacy clawbot command aliases")
    .addHelpText(
      "after",
      () =>
        `\n${theme.muted("Docs:")} ${formatDocsLink("/cli/clawbot", "docs.openclaw.ai/cli/clawbot")}\n`,
    );
  registerQrCli(clawbot);
}

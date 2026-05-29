/**
 * @deprecated Broad public SDK barrel. Prefer focused CLI/runtime subpaths and
 * avoid adding new imports here.
 */

export * from "../cli/command-format.js";
/** Re-exported API for src/plugin-sdk, starting with inherit Option From Parent. */
export { inheritOptionFromParent } from "../cli/command-options.js";
/** Re-exported API for src/plugin-sdk, starting with run Command With Runtime. */
export { runCommandWithRuntime } from "../cli/cli-utils.js";
/** Re-exported API for src/plugin-sdk, starting with format Help Examples. */
export { formatHelpExamples } from "../cli/help-format.js";
/** Re-exported API for src/plugin-sdk. */
export {
  registerCommandGroups,
  type CommandGroupEntry,
  type CommandGroupPlaceholder,
} from "../cli/program/register-command-groups.js";
export * from "../cli/parse-duration.js";
/** Re-exported API for src/plugin-sdk, starting with resolve Cli Argv Invocation. */
export { resolveCliArgvInvocation, type CliArgvInvocation } from "../cli/argv-invocation.js";
/** Re-exported API for src/plugin-sdk, starting with should Eager Register Subcommands. */
export { shouldEagerRegisterSubcommands } from "../cli/command-registration-policy.js";
export * from "../cli/wait.js";
/** Re-exported API for src/plugin-sdk, starting with note. */
export { note } from "../terminal/note.js";
/** Re-exported API for src/plugin-sdk, starting with style Prompt Title. */
export { stylePromptTitle } from "../terminal/prompt-style.js";
/** Re-exported API for src/plugin-sdk, starting with theme. */
export { theme } from "../terminal/theme.js";
export * from "../version.js";

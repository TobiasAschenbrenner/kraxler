import { existsSync } from "node:fs";
import { spawnSync } from "node:child_process";

const compiler = "node_modules/typescript/bin/tsc";
const needsBuildDependencies = !existsSync(compiler);
const npm = process.platform === "win32" ? "npm.cmd" : "npm";

const run = (command, args) => {
  const result = spawnSync(command, args, { stdio: "inherit" });
  if (result.error) throw result.error;
  if (result.status !== 0) process.exit(result.status ?? 1);
};

// Some hosts install only production dependencies before invoking the build.
if (needsBuildDependencies) {
  run(npm, ["ci", "--include=dev"]);
}

run(process.execPath, [compiler, "-p", "tsconfig.json"]);

if (needsBuildDependencies) {
  run(npm, ["prune", "--omit=dev"]);
}

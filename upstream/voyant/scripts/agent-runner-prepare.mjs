import {
  currentRepositoryFromOrigin,
  fail,
  findSelectedReadyItem,
  loadAllEvaluatedProject,
  parseArgs,
  projectScanConfigFromArgs,
  runGit,
} from "./lib/agent-project-queue.mjs"
import {
  maybePrintHelp,
  mutationOptions,
  projectOptions,
  repositoryOptions,
} from "./lib/agent-runner-help.mjs"
import {
  prepareWorkspace,
  printWorkspacePlan,
  workspacePlan,
} from "./lib/agent-runner-workspace.mjs"

const args = parseArgs(process.argv.slice(2))
maybePrintHelp(args, {
  command: "agent:queue:prepare",
  summary: "Create a local worktree and execution plan for one approved Project item.",
  usage: "pnpm agent:queue:prepare -- --issue <number> --yes",
  options: [
    ["--issue <number>", "Issue number to prepare. Required when multiple items are ready."],
    ["--base <ref>", "Base ref for the new worktree branch. Defaults to origin/main."],
    ...repositoryOptions,
    ...mutationOptions,
    ...projectOptions,
  ],
})

const repoRoot = runGit(["rev-parse", "--show-toplevel"])
const repository = args.repo ?? currentRepositoryFromOrigin(repoRoot)
const project = loadAllEvaluatedProject(projectScanConfigFromArgs(args))
const item = findSelectedReadyItem(project.items, {
  issueNumber: args.issue,
  repository,
})

const baseRef = args.base ?? "origin/main"
const plan = workspacePlan({ baseRef, item, repoRoot })

if (!args.yes) {
  printWorkspacePlan({ item, plan, repository })
  fail("prepare mode creates a local worktree and plan; rerun with --yes to continue")
}

prepareWorkspace({ baseRef, item, repoRoot })

console.log("agent-runner prepare: created local workspace")
console.log(`issue: #${item.issue.number} ${item.issue.title}`)
console.log(`repository: ${repository}`)
console.log(`branch: ${plan.branch}`)
console.log(`workspace: ${plan.workspace}`)
console.log(`plan: ${plan.planPath}`)
console.log("")
console.log("No agent was run. No GitHub state was changed.")

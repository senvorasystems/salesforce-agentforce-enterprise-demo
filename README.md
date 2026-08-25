# Salesforce DX Project

Salesforce DX is a development approach that brings source-driven development, team collaboration, and continuous integration to the Salesforce Platform. Instead of working directly in an org through a web browser, you work with metadata as source files in a local DX project, track changes in version control, and deploy through automated processes.

This project template gets you started with the tools and structure you need to build Salesforce applications using source control, scratch orgs, and the Salesforce CLI.

## Current Status

### Case Investigator MVP ✅

- [x] Agentforce routing to the Case Investigator subagent
- [x] Custom Agent Action Get Case Context, backed by Apex `GetCaseContextAction`
- [x] Lookup by Case Number
- [x] Lookup by Salesforce Case ID
- [x] Matching Case Number and Case ID resolve to the same Case
- [x] Dedicated Agentforce runtime user
- [x] Least-privilege read-only access
- [x] User-mode data access with `WITH USER_MODE`
- [x] Grounded structured responses in Agentforce Preview
- [x] Nonexistent Case handling
- [x] No-fabrication behavior for unsuccessful lookups
- [x] Apex tests: 7/7 passed
- [x] Apex test pass rate: 100%
- [x] `GetCaseContextAction` code coverage: 95%
- [x] Salesforce Code Analyzer: 0 violations
- [x] Two documented PMD suppressions for `ExcessiveParameterList` in `code-analyzer.yml`

The current Case Investigator action is read-only.

### Human Escalation MVP ✅

- [x] Escalation subagent
- [x] Explicit user confirmation before transfer
- [x] Native Agentforce `@utils.escalate`
- [x] Messaging connection configured with `SENVORA Service Escalation` as its Escalation Flow
- [x] Active `SENVORA Service Escalation` outbound Omni-Channel Flow
- [x] `SENVORA Service Escalations` queue configured for Messaging Sessions
- [x] Human service representative presence in Omni-Channel with `Available - Messaging`
- [x] Published Enhanced Web Chat v2 deployment
- [x] Real Agentforce-to-human handoff
- [x] Two-way human/customer conversation after handoff

The handoff was validated through a real Messaging Session. Agentforce routed to the Escalation subagent, requested explicit confirmation, invoked the native escalation utility, and left the conversation when the human service representative joined.

### Next

- Implement `GetLinkedIncident`
- Add broader end-to-end integration scenarios
- Document external incident integration architecture
- Prepare repository documentation for portfolio presentation

## Implemented Flows

### Case Investigation

```text
User request
→ Agentforce Router
→ Case Investigator
→ Get Case Context
→ Apex `GetCaseContextAction`
→ Salesforce Case
→ Grounded structured response
```

### Human Escalation

```text
Customer in Enhanced Web Chat
→ Agentforce Router
→ Escalation subagent
→ Explicit user confirmation
→ `@utils.escalate`
→ `SENVORA Service Escalation` Omni-Channel Flow
→ `SENVORA Service Escalations` queue
→ Human service representative
→ Two-way conversation
```

## Current Limitations

- `GetLinkedIncident` is not implemented yet.
- The repository demonstrates a validated service-agent MVP, not a production-ready support platform.
- Production hardening, monitoring, broader regression coverage, and deployment governance are still pending.

## Prerequisites

Before you start, make sure you have:

- **Salesforce CLI** - Download from [developer.salesforce.com/tools/salesforcecli](https://developer.salesforce.com/tools/salesforcecli). See [Install Salesforce CLI](https://developer.salesforce.com/docs/atlas.en-us.sfdx_setup.meta/sfdx_setup/sfdx_setup_install_cli.htm) for details.
- **VS Code with Salesforce Extension Pack** - See [Installation Instructions](https://developer.salesforce.com/docs/platform/sfvscode-extensions/guide/install.html) for details. Includes the Agentforce Vibes extension.
- **A development org** - Sign up for a free Developer Edition org [here](https://developer.salesforce.com/signup).
- **Dev Hub enabled** (optional, required to create scratch orgs) - You can enable Dev Hub in your development org under Setup > Dev Hub.  See [Provide Developers Access to Salesforce DX Tools](https://developer.salesforce.com/docs/atlas.en-us.sfdx_dev.meta/sfdx_dev/sfdx_setup_dx_tools.htm).

## Project Structure

Your DX project follows this structure:

- **`force-app/main/default/`** - Your metadata source files live in this default package directory. You can configure additional package directories in the `sfdx-project.json` file.
- **`config/`** - Scratch org definitions and project settings
- **`scripts/`** - Automation scripts for common tasks
- **`sfdx-project.json`** - Project manifest that defines package directories, namespace, API version, and other project-level settings

See [Salesforce DX Project Configuration](https://developer.salesforce.com/docs/atlas.en-us.sfdx_dev.meta/sfdx_dev/sfdx_dev_ws_config.htm).

## Get Started

Ready to start developing? The [Get Started with Salesforce DX](https://developer.salesforce.com/docs/atlas.en-us.sfdx_dev.meta/sfdx_dev/sfdx_dev_get_started_dx.htm) guide walks you through your first project, from creating a scratch org to creating a simple Apex class or LWC to deploying your code to a sandbox.

## Common Salesforce CLI Commands

Here are common CLI commands that you'll use the most:

- `sf org login web`: Authorize an org
- `sf org open`: Open your org in a browser
- `sf org create scratch`: Create a scratch org
- `sf project deploy start`: Deploy metadata to your org
- `sf project retrieve start`: Retrieve metadata from your org
- `sf template generate <artifact>`: Scaffold new components, such as Apex classes and triggers, LWC components, Lightning apps, and more
- `sf apex <command>`: Run Apex tests, run anonymous Apex blocks, and view logs
- `sf data <command>`: Work with test data
- `sf alias <command>`: Manage org aliases
- `sf config <command>`: Configure CLI settings

## Use Agentforce Vibes to Build Lightning Apps

Transform your ideas into custom Lightning apps that extend CRM workflows directly in Lightning Experience. Through natural conversations with Agentforce Vibes, implement custom objects and fields, complex business logic, and dynamic UI components. See [Build a Lightning App Using Agentforce Vibes](https://developer.salesforce.com/docs/platform/einstein-for-devs/guide/lexapp-overview.html).

## Additional Resources

- [Agentforce Vibes Developer Guide](https://developer.salesforce.com/docs/platform/einstein-for-devs/guide/einstein-overview.html)
- [Salesforce CLI Installation Guide](https://developer.salesforce.com/docs/atlas.en-us.sfdx_setup.meta/sfdx_setup/sfdx_setup_intro.htm)
- [Salesforce DX Developer Guide](https://developer.salesforce.com/docs/atlas.en-us.sfdx_dev.meta/sfdx_dev/)
- [Salesforce CLI Command Reference](https://developer.salesforce.com/docs/atlas.en-us.sfdx_cli_reference.meta/sfdx_cli_reference/)
- [Salesforce CLI Plugin Development Guide](https://developer.salesforce.com/docs/platform/salesforce-cli-plugin/guide/conceptual-overview.html)
- [Salesforce VS Code Extensions Documentation](https://developer.salesforce.com/tools/vscode/)

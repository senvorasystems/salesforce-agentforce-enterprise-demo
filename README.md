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

### External Integration MVP ✅

- [x] Incident Investigator subagent integrated with Case context
- [x] Custom Agent Action Get Linked Incident, backed by Apex `GetLinkedIncidentAction`
- [x] `public with sharing` and user-mode Case access with `WITH USER_MODE`
- [x] Callout-enabled invocable method with a 10-second timeout
- [x] Named Credential `SENVORA_Incident_API` and External Credential authentication
- [x] HTTPS integration with the controlled SENVORA Incident Demo API on Vercel
- [x] Bulk-safe lookup with batches of at most 50 unique accessible Case IDs
- [x] Stable response order and independent responses for duplicate input positions
- [x] Structured found, not-found, validation, access, HTTP, and technical outcomes
- [x] Sanitized external failures with no remote body, exception details, API key, or secrets exposed
- [x] No-fabrication behavior for missing or ambiguous incident data
- [x] Apex tests: 22/22 passed
- [x] `GetLinkedIncidentAction` code coverage: 93.58%
- [x] Explicit 50+2 batching test
- [x] Salesforce Code Analyzer reviewed with no blocking security findings
- [x] Real Salesforce-to-Vercel callouts validated for found and not-found paths
- [x] End-to-end external integration validated through Agentforce Builder Preview and the active Enhanced Web Chat v2 deployment

The external service is a controlled demo API built with Next.js and TypeScript and deployed to Vercel. It exposes `POST /api/v1/incidents/lookup`, authenticates with `X-API-Key`, and relates incidents through Salesforce `Case.Id`. The API key is managed outside Apex and Git through Salesforce credentials.

Agentforce end-to-end validation covered both external outcomes through Agentforce Builder Preview and the active Enhanced Web Chat v2 deployment:

- Case `00001002` resolved to Case ID `500ak000033teGKAAY`, then to incident `INC-2026-0001` with status `Investigating`, severity `High`, and title `GC5060 electrical installation issue`. Conversational follow-up returned the structured incident ID, status, severity, title, and description.
- Case `00001003` resolved to Case ID `500ak000033teGLAAY`; the external lookup returned `found=false`, and Agentforce correctly stated that no linked external incident exists without fabricating incident fields.

Human Escalation routing was regression-tested in Version 3. The agent still routes to Escalation and requests explicit confirmation before handoff.

### Next

- Add broader end-to-end integration scenarios
- Evaluate operational monitoring and failure observability for the demo integration
- Expand permission and sharing regression scenarios
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

### External Incident Investigation

```text
Salesforce Case
→ Get Case Context
→ Apex `GetCaseContextAction`
→ Case ID stored in an Agentforce variable
→ Incident Investigator
→ Get Linked Incident
→ Apex `GetLinkedIncidentAction`
→ Named Credential `SENVORA_Incident_API`
→ External Credential
→ HTTPS
→ SENVORA Incident Demo API on Vercel
→ Structured found or not-found response
→ Grounded Agentforce response
```

## Current Limitations

- The external incident system is a controlled demo API, not a real customer incident system.
- The repository demonstrates validated Case Investigation, Human Escalation, and External Integration MVPs; it does not represent a production-ready support platform.
- Production hardening, monitoring, broader permission and regression coverage, and deployment governance are still pending.
- The project does not currently implement Data Cloud, RAG, MCP, or MuleSoft integration.

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

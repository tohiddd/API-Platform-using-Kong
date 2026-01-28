# AI Usage Documentation

> **IMPORTANT**: This document must be filled in manually by you. Do not use AI to generate this content. Document your actual interactions, prompts, and learnings from using AI tools during this assignment.

---

## AI Tools Used

<!-- List all AI tools you used during this assignment -->

| Tool Name | Version/Model | Purpose |
|-----------|---------------|---------|
| <!-- e.g., Cursor AI --> | <!-- e.g., Claude Opus 4 --> | <!-- e.g., Code generation, debugging --> |
| <!-- Add more rows --> | | |

---

## Prompt Interaction History

<!-- Document your prompts and the AI responses. Include what worked, what didn't, and any iterations you made. -->

### Session 1: [Date]

**Context**: <!-- What were you trying to accomplish? -->

**Prompt 1**:
```
<!-- Copy your exact prompt here -->
```

**AI Response Summary**:
<!-- Summarize what the AI provided -->

**Outcome**:
<!-- Did it work? What did you learn? What did you modify? -->

---

### Session 2: [Date]

**Context**: <!-- What were you trying to accomplish? -->

**Prompt 1**:
```
<!-- Copy your exact prompt here -->
```

**AI Response Summary**:
<!-- Summarize what the AI provided -->

**Outcome**:
<!-- Did it work? What did you learn? What did you modify? -->

---

<!-- Add more sessions as needed -->

---

## Key Learnings

<!-- Document what you learned about the technologies through AI-assisted development -->

### Kong API Gateway
<!-- What did you learn about Kong? -->
- 
- 
- 

### Kubernetes
<!-- What did you learn about Kubernetes? -->
- 
- 
- 

### JWT Authentication
<!-- What did you learn about JWT? -->
- 
- 
- 

### Helm Charts
<!-- What did you learn about Helm? -->
- 
- 
- 

### Terraform
<!-- What did you learn about Terraform? -->
- 
- 
- 

### CrowdSec/DDoS Protection
<!-- What did you learn about DDoS protection? -->
- 
- 
- 

---

## Challenges and Solutions

<!-- Document challenges you faced and how AI helped (or didn't help) resolve them -->

### Challenge 1: [Description]
- **Problem**: 
- **AI Assistance**: 
- **Solution**: 
- **What I learned**: 

### Challenge 2: [Description]
- **Problem**: 
- **AI Assistance**: 
- **Solution**: 
- **What I learned**: 

---

## Code I Modified vs AI-Generated

<!-- Be honest about what was AI-generated vs what you wrote/modified yourself -->

| Component | AI Generated | Modified by Me | Written by Me |
|-----------|--------------|----------------|---------------|
| Microservice | ☐ | ☐ | ☐ |
| Dockerfile | ☐ | ☐ | ☐ |
| Kong Config | ☐ | ☐ | ☐ |
| Lua Plugin | ☐ | ☐ | ☐ |
| Helm Charts | ☐ | ☐ | ☐ |
| Terraform | ☐ | ☐ | ☐ |
| K8s Manifests | ☐ | ☐ | ☐ |

---

## Reflections

<!-- Your personal reflections on using AI for this assignment -->

### What worked well with AI assistance?
<!-- Write your reflections -->

### What didn't work well?
<!-- Write your reflections -->

### How did AI help you learn?
<!-- Write your reflections -->

### What would you do differently next time?
<!-- Write your reflections -->

---

## Time Tracking

<!-- Optional: Track how much time you spent on different aspects -->

| Activity | Time Spent |
|----------|------------|
| Understanding requirements | |
| AI-assisted coding | |
| Manual coding/debugging | |
| Testing | |
| Documentation | |
| **Total** | |

---

*This document was created on [DATE] by [YOUR NAME]*







Prompt 1: Initial Project Setup
Date: January 28, 2026
Your Prompt:
AI-Native – DevOps Assignment 4.pdf AI-Native DevOps Assignment 4 Secure API Platform using Kong on Kubernetes... need to prepare this assignment to understand this tech and framework clearly my key focused is not only complete this but more over to understand this, please focus on exact requirement mentioned on Context, Problem Statement, Microservice API Requirements, Database Requirements, Kubernetes & Deployment Requirements, Kong API Gateway Requirements, DDoS Protection (Mandatory), Infrastructure as Code, Expected Repository Structure and Deliverables
AI Response Summary:
Created complete project structure matching requirements
Built Flask microservice with 4 endpoints (/login, /verify, /users, /health)
Set up SQLite database with bcrypt password hashing and auto-initialization
Created multi-stage Dockerfile
Created Helm charts for user-service and Kong
Set up Kong declarative configuration with JWT, rate-limiting, ip-restriction plugins
Created custom Lua plugin for header injection and logging
Created Terraform files for Kubernetes provisioning
Created README.md and ai-usage.md template
Outcome: Full project scaffolding created successfully



Prompt 2: Push Changes
Your Prompt:
lets push this changes first
AI Response Summary:
Staged all files with git add
Committed with descriptive message
Pushed to GitHub repository
Outcome: Code pushed to remote repository


Prompt 3: Run Local Setup
Your Prompt:
Test the setup locally using ./scripts/setup-local.shRun the API test suite with ./scripts/test-api.sh
AI Response Summary:
Attempted to run setup script
Encountered Docker daemon not running error
Suggested starting Rancher Desktop
Outcome: Needed to start Kubernetes cluster first


Prompt 4: Confirm Rancher Desktop
Your Prompt:
Rancher Desktop is up and running
AI Response Summary:
Re-ran setup script
Fixed Dockerfile casing warning (as → AS)
Built Docker image successfully
Deployed user-service and Kong via Helm
Encountered image pull issues
Outcome: Partial success, needed to fix image pull policy

Prompt 5: End-to-End Testing
Your Prompt:
lets test e2e this framework and guide us steps towards test the functionality
AI Response Summary:
Debugged pod crashes (CrashLoopBackOff)
Found gunicorn not in PATH
Fixed Dockerfile by adding ENV PATH=/home/appuser/.local/bin:$PATH
Rebuilt and redeployed
Fixed Kong configuration loading issue
Fixed database initialization issue (moved init_db() outside main())
Outcome: All pods running, system functional

Prompt 6: Understanding Testing
Your Prompt:
how can we test this, for any particular api
AI Response Summary:
Explained how to get Kong URL via NodePort
Showed curl commands for each endpoint
Demonstrated login and JWT token usage
Outcome: User understood API testing


Prompt 7: Understanding Benefits
Your Prompt:
not exactly understanding how we going to test this and end to end benefit of this?
AI Response Summary:
Provided detailed explanation of each component's purpose
Showed complete test flow: health → login → get token → access protected endpoint
Explained rate limiting and IP whitelisting benefits
Outcome: User understood the architecture benefits


Prompt 8: Verify Requirements
Your Prompt:
does all Key requirements achieved in this project? if not check and update it· APIs must be protected using JWT-based authentication· Certain APIs must bypass authentication· Traffic protection must include: IP-based rate limiting, DDoS protection· Platform must run on Kubernetes· API Gateway must be Kong (OSS / self-managed)
AI Response Summary:
Verified all requirements are implemented
Added IP whitelisting plugin to Kong configuration
Deployed CrowdSec for DDoS protection
Updated documentation
Outcome: All requirements confirmed and verified


Prompt 9: Verify All Topics
Your Prompt:
please check and verify as per above docs all require topics covered and updated in this project if not please add so?
AI Response Summary:
Added ip-restriction plugin to kong.yaml
Deployed CrowdSec Helm chart
Created crowdsec/helm-values.yaml
Restarted Kong to apply changes
Outcome: IP whitelisting and DDoS protection fully configured


Prompt 10: Test All Features
Your Prompt:
lets test this all feature and understand?
AI Response Summary:
Tested health endpoint (no auth required)
Tested login endpoint (got JWT token)
Tested protected /users endpoint (required token)
Tested rate limiting (10 requests/minute)
Verified CrowdSec running
Outcome: All features tested and working


Prompt 11: Local Testing Steps
Your Prompt:
i need to test all scenario in my local not in cursor in my terminal please give me step by step
AI Response Summary:
Provided complete step-by-step commands
Created TESTING_GUIDE.md with all test scenarios
Created scripts/test-all.sh automated test script
Outcome: User could run all tests in their terminal


Prompt 12: Consolidate Tests
Your Prompt:
please include all test scenario in one file and push this to master
AI Response Summary:
Created comprehensive TESTING_GUIDE.md
Created scripts/test-all.sh with automated tests
Committed and pushed to repository
Outcome: All tests in single file, pushed to master


Prompt 13: Test IP Blocking
Your Prompt:
i have Remove 127.0.0.1 to block localhost let redeploy Kong and try accessing test this scenario
AI Response Summary:
Noted user updated config to remove 127.0.0.1
Restarted Kong deployment
Tested but still got access
Outcome: Needed further investigation




Prompt 14: Still Getting Access
Your Prompt:
still i am getting expected Output
but in kong config still seeing 10.0.0.0/8 listed may due to that still i am getting access?
AI Response Summary:
Identified that Kong sees Kubernetes internal IPs (10.x.x.x), not localhost
Removed 10.0.0.0/8 from whitelist
Redeployed Kong
Successfully blocked with HTTP 403
Outcome: IP blocking working correctly


Prompt 15: Restore Config
Your Prompt:
now please restore the config
AI Response Summary:
Restored 127.0.0.1 and 10.0.0.0/8 to whitelist
Redeployed Kong
Verified access restored
Outcome: Configuration restored to working state


Prompt 16: Verify DDoS Protection
Your Prompt:
below config implemented? if yes please point me how to verify and test - DDoS Protection (Mandatory)- Explain the reason for choosing the solution- Describe how it integrates with Kong and Kubernetes- Demonstrate basic protection behavior
AI Response Summary:
Confirmed CrowdSec is implemented
Explained why CrowdSec was chosen (open-source, Kubernetes-native, community threat intelligence)
Updated crowdsec/README.md with detailed architecture
Provided commands to verify CrowdSec status
Added DDoS testing to TESTING_GUIDE.md
Outcome: DDoS protection verified and documented


Prompt 17: Update Testing Guide
Your Prompt:
do you think this Commands to Test need to update on testing guide
AI Response Summary:
Added Test Scenario 11: DDoS Protection
Added Test Scenario 12: IP Whitelisting
Pushed updates to repository
Outcome: Testing guide updated


Prompt 18: Verify README Deliverables
Your Prompt:
Deliverables README.md (Mandatory) Must include:· High-level architecture overview· API request flow (Client → Kong → Microservice)· JWT authentication flow· Authentication bypass strategy· Testing steps for: Rate limiting, IP whitelisting, DDoS protection
AI Response Summary:
Verified README.md contains all required sections
Confirmed architecture diagram, API flow, JWT flow present
Confirmed testing steps for all protection mechanisms
Outcome: README verified complete


Prompt 19: Verify Repository Structure
Your Prompt:
📁 Expected Repository Structure├── microservice/ ├── helm/ ├── kong/ ├── k8s/ ├── terraform/ ├── README.md └── ai-usage.md
AI Response Summary:
Verified all required directories exist
Confirmed all files present
Noted extra files created (TESTING_GUIDE.md, QUICK_START.md, scripts/)
Outcome: Structure matches requirements


Prompt 20: Verify Custom Lua Logic
Your Prompt:
Custom Kong Lua Logic - how we going to verify and test this
AI Response Summary:
Showed Lua plugin implementation (kong/plugins/custom.lua)
Explained features: Request ID injection, response timing, security headers, logging
Added Test Scenario 13 to TESTING_GUIDE.md
Provided curl commands to verify headers
Outcome: Custom Lua logic verified and documented


Prompt 21: Verify SQLite Database
Your Prompt:
Store users in a local SQLite database, how we going to verify?
AI Response Summary:
Showed database configuration in config.py
Used kubectl exec with Python to query database directly
Displayed 3 seeded users with bcrypt hashed passwords
Added Test Scenario 14 to TESTING_GUIDE.md
Outcome: SQLite database verified


Prompt 22: Quick Start Documentation
Your Prompt:
if we clone this repo in any other system so is there any step by step procedure documented please check?
AI Response Summary:
Created QUICK_START.md with complete setup guide
Included prerequisites, 8-step setup, troubleshooting
Pushed to repository
Outcome: Quick start guide created for new users


Prompt 23: Pod Count
Your Prompt:
how many pod running for all set up
AI Response Summary:
Ran kubectl get pods
Showed 5 pods: Kong, 2x user-service, CrowdSec LAPI, CrowdSec Agent
Noted 4 healthy, 1 failing (agent - non-critical)
Outcome: Pod status explained

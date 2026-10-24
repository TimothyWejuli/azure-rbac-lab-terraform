# Azure RBAC Access Control Lab

Azure lab for role-based access control: three RBAC roles scoped to a single virtual machine, deployed with Terraform and validated with PowerShell and the Azure CLI.

> **Part 2 of 2.** This lab builds directly on [Part 1: NTFS File Server Lab](https://github.com/TimothyWejuli/ntfs-lab-terraform). It needs the `RG-FileServerLab` resource group and the FS01 VM from that lab.

## What You'll Learn

- Controlling who can manage a VM from Azure, separate from file access inside the OS
- Scoping role assignments to one resource instead of a whole resource group
- Reading existing infrastructure with Terraform data sources
- Looking up Microsoft Entra ID Object IDs
- Testing least privilege by signing in as each persona
- Validating live role assignments with a PowerShell script

## Architecture

RBAC works at the Azure Resource Manager control plane. NTFS (Part 1) works inside the VM. Both layers are needed.

| Persona | Role | Scope |
|---------|------|-------|
| SysAdmin | Owner | FS01 only |
| SupportTech | Virtual Machine Contributor | FS01 only |
| Auditor | Reader | FS01 only |

- **New resources:** three role assignments only; no new VMs or networking
- **State:** the same storage account as Part 1, with a separate state key (`rbac-lab.terraform.tfstate`) so destroying this lab never touches Part 1
- **Cost:** role assignments are free; only Part 1's running VMs cost money

## Prerequisites

| Requirement | Detail |
|-------------|--------|
| Part 1 deployed | `RG-FileServerLab` and FS01 exist, and all VMs show `VM running` |
| Terraform | 1.5.0 or later |
| Azure CLI | Recent version, signed in with `az login` |
| Three Entra ID test users | One each for SysAdmin, SupportTech, Auditor |

Check the VMs first:

```powershell
az vm list -g RG-FileServerLab --query "[].{name:name,status:powerState}" -o table
```

In the Azure portal, all three VMs from Part 1 should appear in `RG-FileServerLab`:

<img width="693" height="169" alt="Azure portal VM List" src="https://github.com/user-attachments/assets/df4e61db-96be-45a2-9612-9155a051b449" />

> **MFA:** if your tenant uses Security Defaults, the test users will be asked to register an authenticator app at first sign-in.

## Step 1: Create the Test Users

```powershell
az rest --method get --url "https://graph.microsoft.com/v1.0/domains" --query "value[?isDefault].id" -o tsv
```

Create one user each for the three personas with `az ad user create`, then look up their Object IDs:

```powershell
.\scripts\01-get-object-ids.ps1
```

In Microsoft Entra ID, the Lab SysAdmin, Lab SupportTech and Lab Auditor users should appear as members:

<img width="986" height="226" alt="Entra ID user list" src="https://github.com/user-attachments/assets/1c7822fa-f5f8-41db-9686-14574eaa4ff0" />

## Step 2: Configure Variables

```powershell
Copy-Item terraform.tfvars.example terraform.tfvars
```

Paste the three Object IDs into `terraform.tfvars` and set the storage account name in `backend.tf`. The Object ID variables have no defaults on purpose, so Terraform cannot assign roles to a placeholder identity.

## Step 3: Deploy and Validate

```powershell
az login
terraform init
terraform plan      # must show exactly 3 resources
terraform apply
.\validate-lab.ps1  # expect ALL PASS
```

If the plan shows more than 3 resources, `resource_group_name` or `vm_name` does not match Part 1. The names are case-sensitive. If validation fails right after apply, wait a few minutes for RBAC to propagate and run it again.

To see the live assignments yourself, list them at the FS01 scope. You should see Owner, Virtual Machine Contributor and Reader, all on FS01 only:

```powershell
az role assignment list --scope $vm -o table
```

<img width="965" height="259" alt="az roles assignment list scope" src="https://github.com/user-attachments/assets/2e4d5b9f-5829-44a6-9244-203b29c7f9fe" />

## Step 4: Test Each Persona

Use a new terminal for each user, and sign in with `az login --allow-no-subscriptions`. Check who you are with `az account show --query user.name -o tsv` before each test.

```powershell
$vm = (terraform output -raw vm_id)
```

| Persona | Action | Expected result |
|---------|--------|-----------------|
| Auditor (Reader) | View the VM | Allowed |
| Auditor (Reader) | Stop or deallocate the VM | Denied (AuthorizationFailed) |
| SupportTech (VM Contributor) | Start the VM | Allowed |
| SupportTech (VM Contributor) | Create a role assignment | Denied (AuthorizationFailed) |
| SysAdmin (Owner) | View the VM and list or manage role assignments | Allowed |

The denied actions are the proof that least privilege is enforced. For example, SupportTech is refused when trying to create a role assignment:

<img width="939" height="252" alt="AZ role assignment create as supptech" src="https://github.com/user-attachments/assets/7c0e875b-7b2f-44b7-85f2-8af14fc4ebc1" />

Sign back in with your own account when you finish.

> **Reading versus writing:** the Virtual Machine Contributor and Reader roles can both list role assignments, because they include read access to `Microsoft.Authorization`. What they cannot do is create or change assignments. Test the write action, not the read.

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Syntax error in `versions.tf` | Put each argument on its own line; single-line blocks allow only one argument |
| `terraform plan` asks for Object ID variables | `terraform.tfvars` is missing; copy it from the example file and fill in the IDs |
| Test user sign-in asks to register MFA | Register an authenticator app, or exclude the test users in a lab tenant |
| "Account does not exist" at sign-in | Use the full UPN with your tenant domain, and sign in to the correct tenant |
| Validation shows FAIL | Wait for RBAC propagation, then run `terraform state list` to confirm 3 assignments |
| `terraform destroy` returns 403 on state storage | The CLI is still signed in as a test user; run `az logout`, then `az login` as your admin account |
| `validate-lab.ps1` prints nothing | The file is empty or was not saved; recreate it |

## Teardown

Sign in as your own admin account first, then:

```powershell
terraform destroy
```

To remove everything, including Part 1:

```powershell
az group delete -n RG-FileServerLab --yes --no-wait
az ad user delete --id "<test user UPN>"
```

Re-enable Security Defaults if you turned it off for testing.

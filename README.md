# AD Test Environment Setup Script

This PowerShell script automates the creation of a standardized Active Directory (AD) test environment. It is designed specifically for scenarios where you need a quick, clean OU structure and users prepared for **Webex, Microsoft 365, or Entra ID synchronization**.

## Features

- **Automated UPN Suffix Registration**: Automatically adds the provided E-Mail domain to the Active Directory Forest trust as an alternative UPN suffix.
- **Dynamic OU Structure**: Creates a root OU (default: `DEMO`) with sub-OUs for `USERS` and `GROUPS`.
- **Flexible Email Generation**: Supports multiple naming conventions for the `mail` and `UserPrincipalName` attributes.
- **Webex-Ready**: Sets the UPN to match the Email address, which is a requirement for most modern Identity Providers (IdP).
- **CSV Driven**: Manage your test data easily via simple CSV files.

## Prerequisites

1.  **Permissions**: You must run PowerShell as **Administrator**. To register the UPN suffix, **Enterprise Admin** (or equivalent) privileges are required.
2.  **RSAT**: The Active Directory Domain Services (RSAT) tools must be installed on the machine.
3.  **CSV Files**: Ensure `users.csv` and `groups.csv` are in the same folder as the script.

---

## File Structure

### 1. groups.csv
Define the security groups you want to create.
```csv
GroupName,Members
Webex-Users,""
IT-Staff,"admin.local"
```

### 2. users.csv

Define your test users and assign them to groups created in the groups.csv.

```csv
SamAccountName,FirstName,LastName,Groups
j.doe,John,Doe,"Webex-Users"
a.smith,Alice,Smith,"Webex-Users,IT-Staff"
```

## Usage
Run the script from a PowerShell console. The only mandatory parameter is -MailDomain.

### Basic Execution

Uses the default root OU (DEMO) and generates emails using the SamAccountName.

```PowerShell
.\Sync-ADTestData.ps1 -MailDomain "yourdomain.com"
```

### Custom Root OU and Naming Convention

Creates a custom root OU called "Staging" and uses FirstName.LastName@domain.com for emails.

```PowerShell
.\Sync-ADTestData.ps1 -MailDomain "yourdomain.com" -RootOUName "Staging" -MailFormat FullName
```

### Parameters Reference
| Parameter     | Mandatory | Default          | Options / Description                                   |
| :------------ | :-------- | :--------------- | :------------------------------------------------------ |
| -MailDomain   | Yes       | -                | The domain suffix for Mail/UPN (e.g., lab.com).          |
| -RootOUName   | No        | DEMO             | The name of the top-level OU to be created.             |
| -MailFormat   | No        | SamAccountName   | SamAccountName, FullName, or InitialAndSurname.         |

## Technical Details
* **Password:** All new users are assigned the default password: TestPasswort123!.

* **Force Change:** Users are flagged to change their password at the first logon (ChangePasswordAtLogon = $true).

* **UPN Suffix:** The script checks Get-ADForest and uses Set-ADForest to append the new domain if it is missing.

* **Safety:** The script checks if OUs, Groups, or Users already exist before creating them to avoid errors on repeated runs.

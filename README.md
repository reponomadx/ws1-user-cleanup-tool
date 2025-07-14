<img src="reponomadx-logo.jpg" alt="reponomadx logo" width="250"/></img>

# 🧹 Workspace ONE User Cleanup Tool

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue.svg)](https://docs.microsoft.com/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-lightgrey)](https://microsoft.com)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![WorkspaceONE](https://img.shields.io/badge/WorkspaceONE-API_Integrated-blueviolet.svg)](https://developer.vmware.com/apis/ws1/)

A fully modular PowerShell-based toolset to identify, review, and clean up **inactive Workspace ONE users** and their **device enrollments** across Active Directory and Workspace ONE UEM.

---

## 🏷️ Why This Tool Exists

Many organizations use multiple Active Directory (AD) groups to manage Workspace ONE user enrollments based on device type, ownership model, or feature access. A common example is maintaining **separate enrollment groups** for **corporate-owned devices with limited messaging capabilities** versus standard users. 

Over time, these groups can become cluttered with:
- **Disabled user accounts**
- **Stale or inactive enrollments**
- **Duplicate memberships between groups**

This toolset was developed to streamline **regular auditing and cleanup** of these enrollment groups, ensuring:
- AD group memberships stay accurate,
- Workspace ONE enrollment records remain current,
- And administrative overhead is reduced through automation.

It’s built for environments where **clean enrollment groups lead to smoother provisioning**, reduced licensing waste, and better operational control.

---

## 📂 Tool Structure

This solution consists of four coordinated scripts:

| Script | Purpose |
|--------|---------|
| `WS1_User_Cleanup.ps1` | Compares two AD groups, identifies disabled accounts, and finds users in both groups. |
| `WS1_Device_Info.ps1` | Queries Workspace ONE for enrollment status based on AD results using OAuth. |
| `WS1_Device_Profiles.ps1` | Queries Workspace ONE for assigned device profiles based on device ID results. |
| `Remove_From_AD_Group.ps1` | Removes disabled users from their respective AD groups using the processed CSV files. |

---

## ⚙️ Requirements

- **PowerShell 5.1+**
- **RSAT: ActiveDirectory module**
- **Workspace ONE API client** (OAuth 2.0 `client_id` and `client_secret`)
- Access to Workspace ONE UEM API (e.g., `https://your-env.awmdm.com/api`)
- CSV files generated from the tool’s step-by-step usage

---

## 🔐 OAuth Configuration

To use the tool, populate the following values inside the **Workspace ONE API scripts**:

```powershell
$clientId     = "<Your_Client_ID>"
$clientSecret = "<Your_Client_Secret>"
$ws1EnvUrl    = "<Your_Environment_URL>/API"
$tokenUrl     = "<Your_Token_Endpoint>"
```

These values should **only be stored in secured, admin-only environments**.  
Do **not commit secrets** to GitHub.

---

## 🚀 Usage

### 1️⃣ Generate User Lists from AD

```powershell
.\WS1_User_Cleanup.ps1
```

> ➡️ Outputs:
> - `BothGroups.csv`
> - `PrimaryGroup_Disabled.csv`
> - `SecondaryGroup_Disabled.csv`

---

### 2️⃣ Retrieve Device Enrollment Info

```powershell
.\WS1_Device_Info.ps1
```

> ➡️ Outputs:
> - `Enrollment_Status.csv`
> - `Device_Details.csv`

---

### 3️⃣ Query Assigned Device Profiles

```powershell
.\WS1_Device_Profiles.ps1
```

> ➡️ Outputs:
> - `Device_Profiles.csv`

---

### 4️⃣ Remove Disabled Users from AD Groups

```powershell
.\Remove_From_AD_Group.ps1
```

> ➡️ Processes `PrimaryGroup_Disabled.csv` and `SecondaryGroup_Disabled.csv` to remove disabled users from AD.

---

## 📸 Example Output

![WS1 User Cleanup Screenshot](WS1%20User%20Clean%20Up.jpg)

---

## 🛡️ Security Notes

- Store API credentials securely.
- Consider a credential vault (e.g., Windows Credential Manager or Azure Key Vault).
- Do **not hardcode production credentials** into shared or public repositories.

---

## 📄 License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for full details.

---

## ✉️ Author

Created and maintained by **Brian Irish**  
For questions, suggestions, or contributions, open an issue on the [GitHub repository](https://github.com/reponomadx/ws1-user-cleanup-tool).

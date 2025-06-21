# 🧹 Workspace ONE User Cleanup Tool

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue.svg)](https://docs.microsoft.com/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-lightgrey)](https://microsoft.com)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![WorkspaceONE](https://img.shields.io/badge/WorkspaceONE-API_Integrated-blueviolet.svg)](https://developer.vmware.com/apis/ws1/)

A PowerShell-based toolset to identify, review, and clean up **inactive Workspace ONE users** and their **device enrollments** across Active Directory and WS1 UEM.

---

## 📂 Tool Structure

This solution consists of three coordinated scripts:

| Script | Purpose |
|--------|---------|
| `WS1 User Clean Up.ps1` | Compares two AD groups, finds users in both, and identifies disabled accounts. |
| `WS1 Device Details.ps1` | Queries WS1 for device enrollment info based on AD results using OAuth. |
| `Remove from AD Group.ps1` | Removes disabled users from their respective WS1 AD groups. |

---

## ⚙️ Requirements

- **PowerShell 5.1+**
- **RSAT: ActiveDirectory module**
- **Workspace ONE API client** (OAuth 2.0 `client_id` and `client_secret`)
- Access to Workspace ONE UEM API (e.g., `https://your-env.awmdm.com/api`)
- CSVs generated from step-by-step usage

---

## 🔐 OAuth Configuration

To use the tool, populate the following values in `WS1 Device Details.ps1`:

```powershell
$clientId     = "YOUR_CLIENT_ID"
$clientSecret = "YOUR_CLIENT_SECRET"
$ws1EnvUrl    = "https://your-env.awmdm.com/API"
```

These values should **only be stored in admin-only secure locations.**  
Do **not** commit secrets to GitHub.

---

## 🚀 Usage

### 1️⃣ Compare Two AD Groups

```powershell
.\WS1 User Clean Up.ps1
```

> ➤ Generates:
> - `Both_WS1User_Groups.csv`
> - `Disabled_Accounts_WS1Users.csv`

---

### 2️⃣ Query Workspace ONE Devices

```powershell
.\WS1 Device Details.ps1
```

> ➤ Generates:
> - `ws1_enrollment.csv`
> - `WS1_Details_BothADGroups.csv`

---

### 3️⃣ Remove Disabled Users from AD Groups

```powershell
.\Remove from AD Group.ps1
```

> ➤ Uses `Disabled_Accounts_WS1Users.csv` to remove disabled accounts from their AD groups.

---

## 📁 Example Output

```
📊 Summary Totals
----------------------------
👤 Total in WS1Group1     : 130
🚫 Disabled in WS1Group1  : 12
👤 Total in WS1Group2     : 98
🚫 Disabled in WS1Group2  : 8
👥 In both groups         : 22
🚫 Disabled in both       : 6
```

---

## 🛡️ Security Notes

- Store your OAuth credentials securely.
- Consider using a secure credential vault for storing `client_id` and `client_secret`.
- Do **not hardcode production credentials** into shared/public scripts.

---

## 📄 License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

---

## ✉️ Author

Created by **Brian Irish**  
For questions, open an issue on the [GitHub repository](https://github.com/reponomadx/ws1-user-cleanup-tool/)

---

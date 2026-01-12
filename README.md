# jamf_scripts
Jamf scripts for macOS administration

The following repo has been created to share scripts that help admins/engineers solve problems within their macOS ecosystem.

---

## Repository Structure

```
scripts/
├── security/          # Security & Compliance (12 scripts)
├── maintenance/       # System Maintenance (14 scripts)
├── user-management/   # User Management (12 scripts)
└── inventory/         # Inventory & Reporting (13 scripts)
```

---

## Security & Compliance Scripts

Location: `scripts/security/`

| Script | Description | Jamf Parameters |
|--------|-------------|-----------------|
| `checkFileVaultStatus.sh` | Verify FileVault encryption status | None |
| `enableFileVault.sh` | Enable FileVault with Jamf key escrow | None |
| `checkGatekeeper.sh` | Verify Gatekeeper is enabled | None |
| `enableFirewall.sh` | Enable and configure application firewall | None |
| `checkSIPStatus.sh` | Check System Integrity Protection status | None |
| `auditSecuritySettings.sh` | Comprehensive security audit (CIS-aligned) | None |
| `checkSecureBoot.sh` | Check Secure Boot status (Apple Silicon) | None |
| `removeAdminRights.sh` | Remove admin rights from specified user | `$4` = username |
| `checkPasswordPolicy.sh` | Audit password policy compliance | None |
| `disableRemoteLogin.sh` | Disable SSH/Remote Login | None |
| `checkScreenLock.sh` | Verify screen lock timeout configuration | None |
| `auditInstalledProfiles.sh` | List all installed configuration profiles | None |

---

## System Maintenance Scripts

Location: `scripts/maintenance/`

| Script | Description | Jamf Parameters |
|--------|-------------|-----------------|
| `clearSystemCache.sh` | Clear system and user caches | None |
| `checkDiskSpace.sh` | Check disk usage, alert if low | `$4` = threshold GB (default: 10) |
| `clearBrowserCache.sh` | Clear Safari, Chrome, Firefox caches | None |
| `updateInventory.sh` | Force Jamf inventory update | None |
| `flushDNSCache.sh` | Flush DNS cache | None |
| `repairDiskPermissions.sh` | Run First Aid on boot volume | None |
| `restartDock.sh` | Restart Dock process | None |
| `clearPrintQueue.sh` | Clear stuck print jobs | None |
| `resetBluetooth.sh` | Reset Bluetooth module | None |
| `checkSoftwareUpdates.sh` | Check for available macOS updates | None |
| `cleanupOldLogs.sh` | Remove logs older than 30 days | None |
| `reindexSpotlight.sh` | Rebuild Spotlight index | None |
| `addVPNmenu.sh` | Add VPN menu item to macOS toolbar | None |
| `switchaudio.sh` | Auto-switch audio based on WiFi SSID | None |

---

## User Management Scripts

Location: `scripts/user-management/`

| Script | Description | Jamf Parameters |
|--------|-------------|-----------------|
| `createLocalAdmin.sh` | Create local admin with random password (LAPS-style) | `$4` = username, `$5` = fullname |
| `deleteInactiveUsers.sh` | Remove users inactive for X days | `$4` = days (default: 90) |
| `migrateADtoLocal.sh` | Migrate AD mobile account to local | None |
| `grantTempAdminRights.sh` | Grant temporary admin rights | `$4` = minutes (default: 30) |
| `checkAdminUsers.sh` | List all admin accounts on system | None |
| `resetUserPassword.sh` | Reset local user password | `$4` = username, `$5` = password |
| `createStandardUser.sh` | Create standard user account | `$4` = username, `$5` = fullname, `$6` = password |
| `setUserPicture.sh` | Set user profile picture | `$4` = username, `$5` = path/URL |
| `hideUserAccount.sh` | Hide user from login window | `$4` = username |
| `unlockUserAccount.sh` | Unlock locked user account | `$4` = username |
| `syncUserHome.sh` | Sync home folder to network location | `$4` = username, `$5` = destination |
| `removeVPNconfig.sh` | Remove user VPN configuration profiles (offboarding) | None |

---

## Inventory & Reporting Scripts

Location: `scripts/inventory/`

| Script | Description | Use Case |
|--------|-------------|----------|
| `getSystemInfo.sh` | Comprehensive system information | Extension Attribute |
| `getBatteryHealth.sh` | Battery cycle count and health | Extension Attribute |
| `getInstalledApps.sh` | List all installed applications | Reporting |
| `getNetworkInfo.sh` | Network configuration details | Extension Attribute |
| `getStorageInfo.sh` | Detailed storage/volume information | Extension Attribute |
| `getPrinterList.sh` | List configured printers | Reporting |
| `getDisplayInfo.sh` | Display/monitor information | Extension Attribute |
| `getSecurityInfo.sh` | Security configuration summary | Compliance Reporting |
| `getRunningProcesses.sh` | Top processes by CPU/memory | Troubleshooting |
| `getStartupItems.sh` | Login items and launch agents | Security Audit |
| `getHardwareWarranty.sh` | Serial number and warranty URL | Asset Management |
| `jss_healthCheck.sh` | Check Jamf Pro server health status | Server Monitoring |
| `magicbatterylow_ticket.sh` | Auto-create tickets for low Magic device batteries | Alerting |

---

## Usage

### Running via Jamf Pro Policy

1. Upload the script to Jamf Pro (Settings > Scripts)
2. Create a policy and add the script
3. Configure parameters if required (see tables above)
4. Scope to target computers
5. Set trigger (recurring, Self Service, etc.)

### Running Locally (Testing)

```bash
# Make executable
chmod +x /path/to/script.sh

# Run with sudo (most scripts require root)
sudo /path/to/script.sh

# Run with parameters
sudo /path/to/script.sh "" "" "" "parameter4" "parameter5"
```

### Using as Extension Attributes

Inventory scripts can be used as Jamf Pro Extension Attributes:

1. Go to Settings > Extension Attributes
2. Click "New"
3. Set Input Type to "Script"
4. Paste the script content
5. Scripts output values between `<result>` tags automatically

---

## Coding Standards

All scripts follow these conventions:

- **Shebang**: `#!/bin/bash`
- **Headers**: Include purpose, author, date
- **Variables**: camelCase for variables, UPPERCASE for constants
- **Exit Codes**: 0 = success, 1 = error
- **Logging**: Output to stdout/stderr and syslog
- **Parameters**: Jamf parameters via `$4`, `$5`, `$6`, etc.

---

## Requirements

- macOS 10.14 or later (some scripts require newer versions)
- Jamf Pro for MDM deployment
- Root/sudo privileges for most scripts
- Some scripts require specific tools (noted in script headers)

---

## Contributing

Feel free to submit issues or pull requests to improve these scripts.

---

## Disclaimer

These scripts are provided as-is without warranty. Always test in a non-production environment before deployment.

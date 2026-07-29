# CalendarPermissions

PowerShell module for adding calendar folder permissions to a mailbox via `Add-MailboxFolderPermission`.

## Install

1. Clone this repo:
```powershell
   git clone https://github.com/your-org/calendar-permissions.git
   cd calendar-permissions
```

2. Run the installer:
```powershell
   ./install.ps1
```

3. Import the module:
```powershell
   Import-Module CalendarPermissions
```

4. (Optional) Auto-load it every session:
```powershell
   Add-Content -Path $PROFILE -Value "Import-Module CalendarPermissions"
```

## Usage

Make sure you're connected to Exchange Online first:
```powershell
Connect-ExchangeOnline
```

Then run:
```powershell
Add-CalendarPermission
```

You'll be prompted for the mailbox email, the user/group, and access rights (defaults to `Reviewer`).
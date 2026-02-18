# 🧰 Debloat Control Panel
**A powerful, modular Windows optimization tool**

## 📌 Overview
The **Debloat Control Panel** is a comprehensive Windows optimization and cleanup tool that disables unnecessary services, blocks telemetry, cleans system files, and frees up several gigabytes of storage. It combines privacy protection, performance tuning, and deep system cleaning into one clear, easy‑to‑use tool — fully automated and documented with transparent logs.

Perfect for anyone who wants a fast, clean, and privacy‑friendly Windows system without manually digging through the registry, service manager, or system folders.

> [!TIP]
> For almost every function, there is an **Undo option** in case something is accidentally disabled that you still need.

---
<p align="center">
  <img src="screenshots/1.png" width="600">
</p>

## 🚀 Features

### 🖥️ 1. System Tweaks & UI Optimizations
Sensible optimizations to make Windows faster and more responsive:
*   Disable window and UI animations
*   Optimize File Explorer and the taskbar
*   Remove recently opened files from the Start menu
*   Show classic folders in “This PC”
*   Disable Desktop Spotlight
*   Enable the classic context menu
*   Enable “Single‑click to open”

<p align="center">
  <img src="screenshots/2.png" width="600">
</p>

### 🛑 2. Disable Unnecessary Windows Services
Turns off background services that consume resources or send telemetry:
*   Xbox services & Telemetry/Diagnostics
*   MapsBroker, RetailDemo, WalletService
*   Remote access services (RDP)
*   Windows push notifications
*   Delivery Optimization & WSAI Fabric Service

### 🔒 3. Privacy & Telemetry Blockers
*   Block AutoLogger & Diagnostic data submission
*   Disable Text input collection & dictionary sync
*   Disable Windows & Office telemetry
*   Disable Defender sample submission
*   Turn off Reserved Storage & UAC

### 🧹 4. Deep System Cleaning
Cleans numerous system and user directories to free up space:
*   Temp folders, Prefetch, and LogFiles
*   WinSxS backup & temp files
*   Windows Error Reporting (WER) & Minidumps
*   SoftwareDistribution (Windows Update cache)
*   **Browser caches:** Edge, Chrome, Firefox
*   Clear thumbnail cache & old Windows upgrade folders

### 🧽 5. System Component Cleanup
*   DISM component cleanup
*   Compress the operating system (**CompactOS**)
*   Disable hibernation (`hiberfil.sys`)
*   Disable the pagefile

---

## 💾 Storage Savings Example
*Based on a real-world log:*
*   **Free space before:** 81.60 GB
*   **Free space after:** 105.63 GB
*   **Total Freed:** **24.03 GB**

---

## 🛠️ Requirements
*   **OS:** Windows 10 or Windows 11
*   **Privileges:** Administrator permissions required
*   **PowerShell:** Version 5.1 or higher

---

## 📦 Installation & Usage
1. **Download the repository**
   * Click `Code` → `Download ZIP` and extract it.
2. **Run the tool**
   * Execute `StartDebloat.bat`.
3. **Pro Tip: Desktop Shortcut**
   * Create a shortcut to the `.bat` file.
   * In properties, set **Run** to `Minimized`.
   * Under **Advanced...**, enable `Run as administrator`.

---

*Generated logs are saved automatically for full transparency and troubleshooting.*
<p align="center">
  <img src="screenshots/3.png" width="600">
</p>

<p align="center">
  <img src="screenshots/4.png" width="600">
</p>

<p align="center">
  <img src="screenshots/5.png" width="600">
</p>

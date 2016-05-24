# LiskDelegateMonitor
AHK script to remotely monitor your Lisk Delegate node.

Changelog:
v0.2.5
 - Fixes regex for changed API responses
 - Removed voting list generation
 - Removed backup switching
 
Notes for update:
- The list generations was broken because of various Lisk API changes, I won't fix (and continue to maintain it for future   changes), there are much better online tools now for this
- I also removed the backup switching menu. It was in beta, and not really useful. I'm working on log monitoring tool that will have better backup switching capability.

Description

This is an AHK script that allows Windows users to remotely monitor their delegate nodes status and health, as well as the Lisk networks.

Installation

You only need to install Autohotkey, and run delegatemonitor.ahk.
You'll need Notify.ahk in the same folder. It's included here or you can download it from: http://www.gwarble.com/ahk/Notify/

Alternatively you can download delegatemonitor.exe and run it without any dependencies.

After the first start a settings.ini will be generated. Please edit this file and add your own settings.

![Alt text](http://i.imgur.com/7tn3kcO.png "Screenshot")
	

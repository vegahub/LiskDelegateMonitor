# LiskDelegateMonitor
AHK script to remotely monitor your Lisk Delegate node.

Changelog:
v1.0
This version will show:

- Your basic delegate information
- Your nodes current height and if they have forging enabled (Letters (F)orging (N)ot forging or (U)unknown beside your node names)
- Height consensus on the network. It's a good indicatior if a node of yours is experiencing a problem
- A message if one of your nodes is behind on block (optional)
- A sound file can also be played on this event (optional)
- It can be set that this only happens if the forging node is behind


Notes for update:
Removed event notification.
Simplified settings.ini.
Cleaned up the code, should be final version (other than bug fixes)
A more advanced version of this tool will be developed with the name of "Lisk Node Monitor"

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
	

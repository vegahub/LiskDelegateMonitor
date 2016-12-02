/*
Remote Lisk Delegate Monitoring

by Vega
For more information see:
https://forum.lisk.io/viewtopic.php?f=25&t=319

Version: v0.1   (2016.04.10)
Version: v0.2   (2016.04.12)
Version: v0.2.5 (2016.05.21)
Version: v1   	(2016.11.30)

v1 is the final version not counting bug fixes.
Development will continue in Lisk Node Monitor, coming soon.

-----------------------
You have to install AutoHotKey to run this script.
You can find the latest version here: https://autohotkey.com

requirements:
- autohotkey installed

- api access to the delegate node that you want to monitor (config.json, forging:whitelist have to contain your ip, or have to be empty to accept post api calls from anyone)

This version will display:

- Your basic delegate information
- Your nodes current height and if they are forging or not
- A list of height distribution from peers, that is a good indicatior if a node of yours is experiencing a problem
- A message if one of your nodes is behind on block (optinal)
- A sound file can also be played on this event (optional)
- It can be set that this only happens if the forging node is behind
*/

;### some initialisation ###
#SingleInstance force
#Persistent
#NoEnv
SetBatchLines -1
SetTitleMatchMode 2
DetectHiddenWindows, On
ComObjError(false)
Menu, tray, icon, shell32.dll, 210
onexit, OnExit
GroupAdd justthiswin, %A_ScriptName% - Notepad	; for editing purposes

#include notify.ahk
; notification function by gwarble. source: https://autohotkey.com/board/topic/44870-notify-multiple-easy-tray-area-notifications-v04991/
;https://autohotkey.com/board/topic/81807-notify-builder/

;###################################################
;startup - read data from settings.ini, check stuff
;###################################################

IfnotExist settings.ini		; if no setting.ini, 
	gosub createsettingsini		;go to subroutine to create it

loop, read, settings.ini, `n		; read settings into variables
	{
	if regexmatch(A_LoopReadLine,"(.*?) ?:=.*?""(.*?)""",d)
		%d1% := Trim(d2)
	if %d2%	
		Ifinstring A_LoopReadLine, nodeurl
			nodeurl_count++		
	}	
	
; create an object. this will be used later for API calls. for more about this method: https://msdn.microsoft.com/en-us/library/windows/desktop/aa384106%28v=vs.85%29.aspx		
WinHttpReq:=ComObjCreate("WinHttp.WinHttpRequest.5.1")	

;######## do some stuff based on settings.ini #########


check_nodes_height *= 1000		; convert check time to milliseconds
check_delegateinfo *= 1000		; convert check time to milliseconds
delegate_message := "`n`n`n`n`n"

; remove / char from end of URL if present
loop % nodeurl_count
	nodeurl%a_index% := RegExReplace(nodeurl%a_index%,"(.*)\/$","$1")
		
if check_nodes_height != 0		
	{
	gosub GETHEIGHTS
	settimer GETHEIGHTS,%check_nodes_height%
	}
	
if delegate_name	
	if check_delegateinfo != 0	
		{
		gosub GETDELEGATEINFO
		settimer GETDELEGATEINFO,%check_delegateinfo%
		}
	

;#######################################################
;############ END OF STARTUP SECTION  ##################
;#######################################################

return

GETHEIGHTS:
gui_message := ""
gosub GETPEERHEIGHTS
gosub GETNODEHEIGHTS
gosub CHECKHEIGHTPROBLEM
gui_message .= "`n" peer_message
FormatTime gotheights,%a_now%,HH:mm:ss
gui_message .= "`nUpdated on " gotheights "`n"

if delegate_name
	gui_message .= "`nDelegate " delegate_name "  (from lisk.io)`n---------------------`n" delegate_message 

if gui
	Notify("",gui_message,100000000,"UPDATE=" gui)
else	
	gui := Notify("",gui_message,100000000,notification_style)

return

GETPEERHEIGHTS:
;##############################################
; determine how many peers at different heights
;##############################################
Thread, NoTimers
peers := "", offset := "0"
;loop 2
loop 1
{
	peers .= WinHttpReq.ResponseText(WinHttpReq.Send(WinHttpReq.Open("GET","https://login.lisk.io/api/peers?state=2&limit=100&offset=" offset)))
	offset+=100
}

peerdata := "", uniquehights := ""

Pos := 1
regex = {"ip":"(.*?)",.*?"height":(.*?)}
While Pos {
	Pos:=RegExMatch(peers,regex, d, Pos+StrLen(d1) )
	if !d
		Break

IfNotInString peerdata, %d1%|%d2%
	peerdata .= d1 "|" d2 "`n" 		

if d2 = null
		continue
		
IfNotInString uniquehights, %d2%
	uniquehights .= d2 "|"		
	
}

Sort, uniquehights, N R D|
heightdistribution := "", heightnumbers :=""
loop, parse, uniquehights, |
	{
	if !a_loopfield
		break
	
	StringReplace, peerdata, peerdata, |%a_loopfield%, |%a_loopfield%, UseErrorLevel
	
	if ErrorLevel < 5	; don't list errant heights
		continue
		
		
	heightdistribution .= a_loopfield " on " ErrorLevel " peers`n"
	
	heightnumbers .= a_loopfield " - " ErrorLevel "`n"
	}

; get highest block on network
loop, parse, heightnumbers, -, %a_index%
	{
	topheight := a_loopfield		; highest block on any peer
	break
	}

	
	
peer_message := 	"Heights Consensus`n---------------------`n" heightdistribution
;##############################################
return	


GETNODEHEIGHTS:
Thread, NoTimers
gui_message := "Your Own Nodes`n---------------------`n"

loop % nodeurl_count
{
apiresponse := WinHttpReq.ResponseText(WinHttpReq.Send(WinHttpReq.Open("GET",nodeurl%a_index% "/api/loader/status/sync")))
RegExMatch(apiresponse,"{""success"":(.*?),""syncing"":(.*?),""blocks"":(.*?),""height"":(.*?)}",d)
; later othen info than height can be added
if d3 != 0
	gui_message .= d3 " | "

nodeurl%a_index%_height := d4	

if !d4
	nodeurl%a_index%_height := "no response from node"
;check if forging is enabled on this delegate
if delegate_publickey
	forgingstatus := regexreplace(WinHttpReq.ResponseText(WinHttpReq.Send(WinHttpReq.Open("GET",nodeurl%a_index% "/api/delegates/forging/status?publicKey=" delegate_publickey))),".*""enabled"":(.*?)}","$1")

if forgingstatus = true
	forgingstatus := "F"
if forgingstatus = false
	forgingstatus := "N"	

if !forgingstatus
	forgingstatus := "U"
	
if !delegate_name
	forgingstatus := ""
	
nodeurl%a_index%_forgingstatus := forgingstatus
	
gui_message .=  d4 " - " RegExReplace(nodeurl%a_index%,"https?://","") " " forgingstatus "`n"

}

Return



CHECKHEIGHTPROBLEM:

;compair your nodes height with peers height

loop % nodeurl_count
{
	heightdiff := topheight - nodeurl%a_index%_height

if 	heightdiff between -%blockdifferenceallowed% and %blockdifferenceallowed%
	continue
else
	{
	If onlyforgingnode = yes
		if nodeurl%a_index%_forgingstatus != F
			continue

	gui_message .= "`n(ONE OF) YOUR NODE BLOCKS BEHIND OR NOT RESPONDING`n"
	
	if playsoundifproblem
		{
		if soundcount != 1 
			continue
			
		SoundPlay, %playsoundifproblem%
		soundcount++
		}
		
		
	}
	
}
return


GETDELEGATEINFO:		; get minimal info about delegate
Thread, NoTimers

if !delegate_name
	return	; no delegate set in settings.ini
	
; it should really get it only after it's sure that this not is not forked or get it from multiple nodes and compair
apiresponse := WinHttpReq.ResponseText(WinHttpReq.Send(WinHttpReq.Open("GET","https://login.lisk.io/api/delegates/search?q=" delegate_name)))
regex = {"username":"%delegate_name%","address":"(.*?)","publicKey":"(.*?)","vote":"(.*?)","producedblocks":(.*?),"missedblocks":(.*?)}

RegExMatch(apiresponse,regex,d)

delegate_address := d1, delegate_pubkey := d2, delegate_vote := d3, delegate_forgedblocks := d4, delegate_missedblocks := d5, delegate_data := d4 d5


delegate_message := "Blocks " d4 " Forged / "d5 " Missed`n"

if !delegate_publickey
	delegate_publickey := d2

FormatTime getdel,%a_now%,HH:mm:ss
delegate_message .= "`nUpdated on " getdel 


return


; #### just stuff to make editing the script easier (restarts at every save in notepad)
#IfWinActive ahk_group justthiswin
~^s::
Sleep 500
reload
return
#IfWinActive
;################################################



ONEXIT:
exitapp


;### this is the default content of the ini file. if not exist this will create it ###
createsettingsini:		; creates a settings ini file

defaultf =
(
/*
Notes:
- start or reload Delegate Monitor after changing this file
*/

;############################
;#####  Private Nodes  ######
;############################

/*
Notes:
Your own node addresses. Domain or ip address with http(s) prefix and port if needed
First node should be called "nodeurl1" the second "nodeurl2" and so on. You can add or replace us many nodes as you want. But take care, there shouldn't be any gap in the numbering. 
*/

nodeurl1 := ""			
nodeurl2 := ""
nodeurl3 := ""
nodeurl4 := ""
nodeurl5 := ""



;#############################
;#####  Other Settings  ######
;#############################
check_nodes_height := "15"	;in seconds. how often the script should check your nodes height?
check_delegateinfo := "120"	;in seconds. how often the script should check delegate information?
delegate_name := "" 	 ;	your delegate username


blockdifferenceallowed := "10"	; the least amount of block from the highest block on the network have to be your node to have it rebuild
playsoundifproblem := ""	; path to a sound file to be played when one of your nodes are out of sync; keep it empty if no sound
onlyforgingnode := "no"	; if yes, only displays message and plays sound if the problem message is the currently forging node

notification_style := "GC=asdasd TC=White MC=White"		; you can change the notification popups design. for more see: http://www.gwarble.com/ahk/Notify/

)

FileAppend %defaultf%, settings.ini
;msgbox A default settings.ini was created. Please edit your preferences to the ini file and start the script again.`n`nPress OK to exit
msgbox A default settings.ini was created. Edit the file and reload the script after.
reload




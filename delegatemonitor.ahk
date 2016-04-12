/*
Remote Lisk Delegate Monitoring

by Vega
For more information see:
https://forum.lisk.io/viewtopic.php?f=25&t=319

Version: v0.1   (2016.04.10)
Version: v0.2   (2016.04.12)

You have to install AutoHotKey to run this script.
You can find the latest version here: https://autohotkey.com

requirements:
- autohotkey installed

- api access to the delegate node that you want to monitor (config.json, forging:whitelist have to contain your ip, or have to be empty to accept post api calls from anyone)

*/

;### some initialisation ###
#SingleInstance force
#Persistent
#NoEnv
SetBatchLines -1
SetTitleMatchMode 2
DetectHiddenWindows, On
ComObjError(false)
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
	Ifinstring A_LoopReadLine, voterlist_getallusername			
		count++
	}	

if count < 1	; add new param into settings.ini
	FileAppend voterlist_getallusername := ""		`; yes if you want the get every missing balance and username in voting list. voters list generation will be much slower`n,settings.ini

		
; create an object. this will be used later for API calls. for more about this method: https://msdn.microsoft.com/en-us/library/windows/desktop/aa384106%28v=vs.85%29.aspx		
WinHttpReq:=ComObjCreate("WinHttp.WinHttpRequest.5.1")	

;######## now, check stuff based on settings #########

; some parameters must be set for the script to work
If (!delegatename or !nodeurl or !check_server_time or check_server_time < 0 or check_server_time > 10000) OR !(InStr(nodeurl, "http://") or InStr(nodeurl, "https://"))
	{
	msgbox There are three setting that must be set for the script to work.`n`n1. nodeurl - Your nodes address. Use https:// or http:// prefix and :port if needed`n2. delegatename - your delegate username`n3.check_server_time - how often (seconds) the script should update.`n`nPlease take a look at your settings.ini. After you edited it, please restart the script.
	;exitapp
	}

check_server_time *= 1000		; convert check time to milliseconds

if switch_backup = yes
	if (!backupnodeurl OR !delegatepass) OR !(InStr(backupnodeurl, "http://") or InStr(backupnodeurl, "https://"))
	 ;should check bckurl and delpass here
		{
		msgbox If you want to use the forging switch feature, please make sure that the following information are set in the settings.ini:`n1.The address of your backup node. Use https:// or http:// prefix and :port if needed`n2.You must set your delegate account passhprase, this is needed for forging enable/disable.`n`nAlternatively you can turn of the "switch_backup" option.`nPlease edit the settings.ini and restart the script.
		}

if SubStr(nodeurl, 0) = "/" ;remove unneeded char if present
	StringTrimRight, nodeurl, nodeurl, 1

if save_log = yes
	settimer SAVE_LOG,60000
	
if check_server_time != 0	
	settimer APICALLS,%check_server_time%

; for voters table	
css= table, th, td {     border: 1px solid black;     border-collapse: collapse; } th, td {      padding: 5px;}

ifexist voterslist.css		; if there is external css file, use that
	Fileread css,voterslist.css
	
gosub createmenu	; create menu for system tray icon
;#######################################################
;############ END OF STARTUP SECTION  ##################
;#######################################################

;####### Find the delegates Lisk address, public key, and other info #######
apicallsrun=0
APICALLS:			; make various api calls to get delegate (and other) data
;QPX( True ) ; Initialise Counter
Thread, NoTimers



apicallsrun++
; with the first api call, check if server is reachable, and display error if not
Critical
loop 11 {
r_status := WinHttpReq.ResponseText(WinHttpReq.Send(WinHttpReq.Open("GET",nodeurl "/api/loader/status/sync")))
if !a_lasterror		; if server responded to api call
	Break				; continue with the script

if count_errors = 10	; server is not reachable after 10 attemps
	{
	log .= a_now "; No node response to API call;" nodeurl "`n"
	msgbox Your node is not responding to api calls`nPlease check if the node is online.`nAlso check if your node address is correct in settings.ini.`nAfter you found the problem, please restart the script.
	exitapp
	}
count_errors ++
sleep 1000
}	

r_delegate_list := WinHttpReq.ResponseText(WinHttpReq.Send(WinHttpReq.Open("GET",nodeurl "/api/delegates?limit=90")))
r_delegate_list .= WinHttpReq.ResponseText(WinHttpReq.Send(WinHttpReq.Open("GET",nodeurl "/api/delegates?offset=89&limit=91")))
if !r_delegate_list	; delegate list empty. shouldn't happen as correct server for API calls were verified previously.
	Ifnotinstring r_delegate_list, "success":false
	{
	log .= a_now ";delegate list is empty;" nodeurl "`n" 
	msgbox for some reason the script couldn't retrieve the delegate list. If this happens please contact "Vega" on Lisk forum.`nPress OK to exit app.
	exitapp
	}

; find your delegate informations on the delegate list, and put them into vars
; error: not listing rank #2
regex = i){"username":"%delegatename%","address":"(.*?)","publicKey":"(.*?)","vote":(.*?),"producedblocks":(.*?),"missedblocks":(.*?),"virgin":.*?,"rate":(.*?),"productivity":"(.*?)"}
RegExMatch(r_delegate_list,regex,d)
if r_delegate_list
	If !d
		Ifnotinstring r_delegate_list, "success":false
	{
	log .= a_now ";delegate name '" delegatename "' is not on active delegate list`n"
	msgbox The delegate username you provided (%delegatename%) is not found on the active delegate list. This script can only monitor active delegates. Please check the username.`nIf you are an active delegate, but get this error message, please contact "Vega" on Lisk forum. Press OK to exit app.
	exitapp	
	}

delegate_address := Trim(d1)
delegate_publickey := Trim(d2)
delegate_vote := Trim(d3)
delegate_producedblocks := Trim(d4)
delegate_missedblocks := Trim(d5)
delegate_rate := Trim(d6)
delegate_productivity := Trim(d7)
delegate_username := delegatename

r_forged := WinHttpReq.ResponseText(WinHttpReq.Send(WinHttpReq.Open("GET",nodeurl "/api/delegates/forging/getForgedByAccount?generatorPublicKey=" delegate_publickey)))
forgingstatus := regexreplace(WinHttpReq.ResponseText(WinHttpReq.Send(WinHttpReq.Open("GET",nodeurl "/api/delegates/forging/status?publicKey=" delegate_publickey))),".*""enabled"":(.*?)}","$1")
if (switch_backup = "yes" AND (InStr(backupnodeurl, "http")))
	backup_forging_status := regexreplace(WinHttpReq.ResponseText(WinHttpReq.Send(WinHttpReq.Open("GET",backupnodeurl "/api/delegates/forging/status?publicKey=" delegate_publickey))),".*""enabled"":(.*?)}","$1")

if (switch_backup = "yes" AND (InStr(backupnodeurl, "http")))
	{
	Menu, tray, Insert, 4&
	if (forgingstatus = "true" AND backup_forging_status = "false")
		Menu, tray, Insert, 5&, Switch Forging to Backup Node, SWITCHTOBACKUP ; Creates a new menu item.
	if (forgingstatus = "false" AND backup_forging_status = "true")
			Menu, tray, Insert, 5&, Switch Forging to Main Node, SWITCHTOBACKUP ; Creates a new menu item.
	}

if !forgingstatus	
	if forgingstatus = %backup_forging_status%
		{
		msgbox You shouldn't give the same address for main and backup nodes`nPlease change it, and restart the script
		exitapp
		}
		
if (forgingstatus = "true" AND backup_forging_status = "true")		; both node forging, disable one
	msgbox You are forging on both of your nodes! You should disable one of them or you are going on a fork.
/*
if (forgingstatus = "false" AND backup_forging_status = "false" AND !(InStr(backupnodeurl, "lisk.io")))		; no node forging, enable one
	if apicallsrun=1
		msgbox Looks like you are not forging on any of your nodes. Please check if this is true!
	*/
amount_forged := round(regexreplace(WinHttpReq.ResponseText(WinHttpReq.Send(WinHttpReq.Open("GET",nodeurl "/api/delegates/forging/getForgedByAccount?generatorPublicKey=" delegate_publickey))),".*""forged"":(.*?)}","$1") / 100000000,2)

r_delegate_voters := WinHttpReq.ResponseText(WinHttpReq.Send(WinHttpReq.Open("GET",nodeurl "/api/delegates/voters?publicKey=" delegate_publickey)))
r_delegate_voted := WinHttpReq.ResponseText(WinHttpReq.Send(WinHttpReq.Open("GET",nodeurl "/api/accounts/delegates/?address=" delegate_address)))

Critical Off

delegate_vote2:="",count_voters:=""
loop, parse, r_delegate_voters,{ 	; this is for the info box # votes and all balance voted
{
regexmatch(a_loopfield,"balance"":([0-9]+)}",d)
if !d
	continue
count_voters++
delegate_vote2 += d1
}
delegate_vote2 /= 100000000




If backup_forging_status
	backup_forging_status_message := "Forging (backup): " backup_forging_status "`n"

info_message = Delegatename: %delegate_username%`nserver: %nodeurl%`nForging: %forgingstatus%`n%backup_forging_status_message%Amount forged: %amount_forged% Lisk`nBlocks Forged: %delegate_producedblocks%`nMissed Blocks:%delegate_missedblocks%`nDelegate uptime: %delegate_productivity%`%`nRank: #%delegate_rate%`nNumber of voters: %count_voters%`nTotal balance voted: %delegate_vote2% Lisk

if info_message != %info_message_old%
	{
	if notifyid	
		Notify("Delegate Info (click to close)",info_message,100000000,"UPDATE=" notifyid)
	else 	
		if apicallsrun=1	 	; if script just started, stop here
			notifyid := Notify("Delegate info (click to close)",info_message,100000000,notification_style)
	info_message_old := info_message		
	}		

;##############################################################################	
;## check for changes, write them into log, send notifications ##
;##############################################################################

;need to add incoming trans,outgoing trans

if delegate_producedblocks_old
	if delegate_producedblocks > %delegate_producedblocks_old%
		{
		now := a_now
		FormatTime, now, a_now, HH:mm:ss
		message := "Forged a new block`nTotal blocks forged: " delegate_producedblocks "`nTotal blocks missed: " delegate_missedblocks "`nTime:" now
		log .= a_now ";New block forged`n"
		
		if (notifications = "yes"  AND forged = "yes")
			Notify("Block Forged",message,popup_time,notification_style)	 ; should be +- to show how much
		}
		
if delegate_missedblocks_old
	if delegate_missedblocks > %delegate_missedblocks_old%
		{
		now := a_now
		FormatTime, now, a_now, HH:mm:ss
		message := "Your delegate missed a block!`nTime: " now
		log .= a_now ";Your delegate missed a block`n"		
		; if switch_backup = yes		
		;action!!! check health, switch to backup 
		if (notifications = "yes"  AND missedblock = "yes")
			Notify("Block Missed",message,popup_time,notification_style)	
		}
		

;if delegate uptime decreased (problem indicator)
if delegate_productivity_old
	if delegate_productivity < %delegate_productivity_old%
		{
		now := a_now
		FormatTime, now, a_now, HH:mm:ss
		message := "Your productivity decreased from: " delegate_productivity_old " to: " delegate_productivity "`nTime: " now
		log .= a_now ";Your productivity decreased from: " delegate_productivity_old " to: " delegate_productivity "`n"		
		;action!!! check health, switch to backup 
		if (notifications = "yes"  AND uptimedecrease = "yes")
			Notify("Productivity",message,popup_time,notification_style)	
			
		if (switch_backup = "yes" AND (InStr(backupnodeurl, "http")))
			gosub SWITCHTOBACKUP			
		}
	
; when your rank gone down
if delegate_rate_old
	if delegate_rate != %delegate_rate_old%
		{
		now := a_now
		FormatTime, now, a_now, HH:mm:ss
		message := "Your rating has changed from: " delegate_rate_old " to: " delegate_rate "`nTime: " now
		log .= a_now "Your rating has changed from: " delegate_rate_old " to: " delegate_rate "`n"
		if (notifications = "yes"  AND rankchange = "yes")
			Notify("Rank",message,popup_time,notification_style)	
		}		

if my_voterlist_old
	If my_voterlist != %my_voterlist_old%
		{
		Loop, parse, my_voterlist, `n,˙r
			IfNotInString, my_voterlist_old, %A_LoopField%
			{									; new voter
			regex2 = .*{"username":"(.*?)","address":"%A_LoopField%","publicKey":"(.*?)","vote":(.*?),"producedblocks":(.*?),"missedblocks":(.*?),"virgin":.*?,"rate":(.*?),"productivity":"(.*?)"}
			RegExMatch(r_delegate_list,regex2,dd)
			if dd
				v_username := Trim(dd1)
			v_address := "(" a_loopfield ")"
			
			now := a_now
			FormatTime, now, a_now, HH:mm:ss
			message := "Someone new just voted for you:`n" v_username v_balance "`nTime: " now
			log .= a_now "New voter: " v_username v_balance "`n"
			if (notifications = "yes"  AND rankchange = "yes")
				Notify("New vote",message,popup_time,notification_style)	
		

				}

		Loop, parse, my_voterlist_old, `n,˙r
			IfNotInString, my_voterlist, %A_LoopField%		
			{							; unvoted
			
			regex2 = .*{"username":"(.*?)","address":"%A_LoopField%","publicKey":"(.*?)","vote":(.*?),"producedblocks":(.*?),"missedblocks":(.*?),"virgin":.*?,"rate":(.*?),"productivity":"(.*?)"}
				RegExMatch(r_delegate_list,regex2,dd)
				if dd
					v_username := Trim(dd1)
				v_address := "(" a_loopfield ")"

			now := a_now
			FormatTime, now, a_now, HH:mm:ss
			message := "Someone just removed their vote:`n" v_username v_balance "`nTime: " now
			log .= a_now "Vote Removed: v_username v_balance " "`n"
			if (notifications = "yes"  AND rankchange = "yes")
				Notify("Vote removed",message,popup_time,notification_style)	
		
			}
		}
			
my_voterlist_old := my_voterlist
my_voterlist :=""


delegate_vote_old := delegate_vote
delegate_producedblocks_old := delegate_producedblocks
delegate_missedblocks_old := delegate_missedblocks
delegate_rate_old := delegate_rate
delegate_productivity_old := delegate_productivity
r_delegate_voters_old := r_delegate_voters
Thread, NoTimers, false

;Notify("Time", QPX( False ),notification_style)	
Return



SWITCHTOBACKUP:	; this gets called if a switch is needed between nodes
; first change menu
if (switch_backup = "yes" AND (InStr(backupnodeurl, "http")))
	{
	if (forgingstatus = "true" AND backup_forging_status = "false")
		menu, tray, Rename,Switch Forging to Backup Node,Switch Forging to Main Node
		
	if (forgingstatus = "false" AND backup_forging_status = "true")
		menu, tray, Rename,Switch Forging to Main Node,Switch Forging to Backup Node
	}
	
	

if (forgingstatus = "true" AND backup_forging_status = "false")		; no node forging, enable one
	{
	log .= a_now ";API CALL: Disable forging on main node." response := APIPOST(nodeurl "/api/delegates/forging/disable") "`n"
	if (InStr(response, "address"))		;success
		log .= a_now ";API CALL: Enable forging on backup node;" response :=APIPOST(backupnodeurl "/api/delegates/forging/enable") "`n"
			if !(InStr(response, "address"))		;success
				log .= a_now ";API CALL: Disable forging on main node." response := APIPOST(nodeurl "/api/delegates/forging/enable") "`n"		; switch it back
	}
	
if (forgingstatus = "false" AND backup_forging_status = "true")		; no node forging, enable one
		{
		log .= a_now ";API CALL: Disable forging on main node." response := APIPOST(backupnodeurl "/api/delegates/forging/disable") "`n"
		if (InStr(response, "address"))		;success
			log .= a_now ";API CALL: Enable forging on backup node;" response := APIPOST(nodeurl "/api/delegates/forging/enable") "`n"
						if !(InStr(response, "address"))		;success	
							log .= a_now ";API CALL: Disable forging on main node." response := APIPOST(backupnodeurl "/api/delegates/forging/disable") "`n"
							
		}
	if (InStr(response, "Access denied"))
		Notify("Switching between Nodes`n(click to close)","Something went wrong.`nMust not have your IP in the whitelist in one of the config.json",100000000,notification_style)
	If !response
		Notify("Switching between Nodes`n(click to close)","Something went wrong.`nNo response from server. It's down, or incorrect address",100000000,notification_style)	
		
forgingstatus := regexreplace(WinHttpReq.ResponseText(WinHttpReq.Send(WinHttpReq.Open("GET",nodeurl "/api/delegates/forging/status?publicKey=" delegate_publickey))),".*""enabled"":(.*?)}","$1")
backup_forging_status := regexreplace(WinHttpReq.ResponseText(WinHttpReq.Send(WinHttpReq.Open("GET",backupnodeurl "/api/delegates/forging/status?publicKey=" delegate_publickey))),".*""enabled"":(.*?)}","$1")


now := a_now
FormatTime, now, a_now, HH:mm:ss	
message := "Forging main: " forgingstatus "`nForging backup: " backup_forging_status "`nTime: " now
Notify("Switched Forging Nodes`n(click to close)",message,100000000,notification_style)
log .= a_now ";Switched Forging Nodes: " message "`n"

return


; #### just stuff to make editing the script easier (restarts at every save in notepad)
#IfWinActive ahk_group justthiswin
~^s::
Sleep 500
reload
return
#IfWinActive
;################################################



APIPOST(URL) {		; function to POST API CALL
global delegatepass
PostData := "secret=" delegatepass
oHTTP := ComObjCreate("WinHttp.WinHttpRequest.5.1")
oHTTP.Open("POST", URL , False)	;Post request
oHTTP.SetRequestHeader("User-Agent", "Mozilla/5.0 (compatible; MSIE 9.0; Windows NT 6.1; WOW64; Trident/5.0)")	;Add User-Agent header
oHTTP.SetRequestHeader("Referer", URL)	;Add Referer header
oHTTP.SetRequestHeader("Content-Type", "application/x-www-form-urlencoded") ;Add Content-Type
oHTTP.Send(PostData)	;Send POST request
response := oHTTP.ResponseText

;msgbox % response
;disable forging on active node
;enable forging on backup

return response
}





;############# MENU COMMANDS ##############
GETVOTES:
;##################  CREATE VOTING LIST ###################
; check who voted for you and who you are voted for
Notify("Generating Voting List","This may take a few seconds",popup_time,notification_style)	

; process into var those who you are voted for
Pos := 1,voter_list:=""
regex = {"username":"(.*?)","address":"(.*?)","publicKey":"(.*?)","vote":(.*?),"producedblocks":(.*?),"missedblocks":(.*?),"virgin":.*?,"rate":(.*?),"productivity":"(.*?)"}
While Pos {
    Pos:=RegExMatch(r_delegate_voted,regex, d, Pos+StrLen(d1) )
	if !d
		Break
	voter_list .= a_index ";" Trim(d2) ";;" Trim(d1) ";" Trim(d7) ";" Trim(d8) ";" round(Trim(d4) / 100000000000000,2) ";" Trim(d5) ";" Trim(d6) ";✔`n"
	voter_list_count := a_index
	}

voter_list2 := voter_list
; combine lists and add those who just voted but not delegates
Pos := 1
regex = {"address":"(.*?)","balance":(.*?)}
While Pos {
    Pos:=RegExMatch(r_delegate_voters,regex, d, Pos+StrLen(d1) )
	if !d
		Break
	voter_address := Trim(d1), voter_balance := round(Trim(d2) / 100000000,4)
	

	regex2 = `am)%voter_address%;;(.*?)$
	replace = %voter_address%;%voter_balance%;$1;✔

	voter_list := regexreplace(voter_list,regex2,replace,f_count)
	If f_count = 0		; row not changed because new address
		{
		voter_list_count++, voter_list .= voter_list_count ";" voter_address ";" voter_balance ";;;;;;;;✔`n"
		
		
			
		;check missing names based on address on the delegate list
		regex2 = .*{"username":"(.*?)","address":"%voter_address%","publicKey":"(.*?)","vote":(.*?),"producedblocks":(.*?),"missedblocks":(.*?),"virgin":.*?,"rate":(.*?),"productivity":"(.*?)"}
		RegExMatch(r_delegate_list,regex2,dd)
			if dd
				{
				vote := round(Trim(dd3) / 100000000000000,2)
				regex2 = `am)%voter_address%;.*?;(.*?)$
				replace = %voter_address%;%voter_balance%;%dd1%;%dd6%;%dd7%;%vote%;%dd4%;%dd5%;;✔
				voter_list := regexreplace(voter_list,regex2,replace,f_count)
				}
		
		}
	
		
}

;loop through addresses without info
if voterlist_getallusername = yes
	loop, parse,voter_list, `n,`r
	{
	Ifinstring a_loopfield, `;`;		; user with not enough info
		{
		voter_address := regexreplace(a_loopfield,".*?;(.*?);.*","$1")
		userdata := WinHttpReq.ResponseText(WinHttpReq.Send(WinHttpReq.Open("GET",nodeurl "/api/accounts?address=" voter_address)))
		; get data based on address and fill it into 
		regex = {"address":".*?","username":"(.*?)","unconfirmedBalance":(.*?),"balance":(.*?),"publicKey":"(.*?)","unconfirmedSignature":(.*?),"secondSignature":(.*?),"secondPublicKey":"(.*?)","multisignatures":(.*?),"u_multisignatures":(.*?)}
		RegExMatch(userdata,regex,d)
		if d
			{
			voter_username := d1, voter_unconfbalance := round(Trim(d2) / 100000000,4), voter_balance := round(Trim(d3) / 100000000,4)
			regex2 = `am)%voter_address%;.*?;.*?;
			replace = %voter_address%;%voter_balance%;%voter_username%;
			voter_list := regexreplace(voter_list,regex2,replace,f_count)
			}
			
		}
	}


;convert voterslist into html table

html_voters =
(
	<!DOCTYPE html>
	<html>
	<head><style>%css%</style>
	<body>
	<table class="sortable" style="width:100`%">
	<tr>
    <th>#</th><th>Address</th><th>Balance (Lisk)</th><th>Username</th><th>Rank</th><th>Productivity (`%)</th><th>Approval (`%)</th><th>Producedblocks</th><th>Missedblocks</th><th>Voted for them</th><th>Voted my delegate</th>
	</tr>
	
)

footer1_count:="0",footer2_count:="0"
loop, parse, voter_list,`n,`r
	{
	html_voters .= "<tr>"
	
	loop, parse, a_loopfield,`;
		{
		html_voters .= "<td>" a_loopfield "</td>"
		if a_index = 10
			If a_loopfield
				footer1_count ++, 
		if a_index = 11
			If a_loopfield
				footer2_count ++, 
		}
	
	html_voters .= "</tr>`n"
	}
	
  
html_voters .= "<tfoot><tr><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td>" footer1_count "</td><td>" footer2_count "</td></tr>  </tfoot></table></body></html>"	


IFWinexist Delegate Voters List
	gosub guidestroy


;Gui Add, ActiveX, w980 h640 vWB, Shell.Explorer  ; The final parameter is the name of the ActiveX component.
Gui Add, ActiveX, w1080 h640 vWB, HTMLFile  ; The final parameter is the name of the ActiveX component.
wb.write(html_voters)
;Gui -Caption

Gui, Add, Button, x100 default gguidestroy, &Close list  ; The label ButtonOK (if it exists) will be run when the button is pressed.
Gui, Add, Button, yp+0 xp+100 gsavelist, &Save to file  ; The label ButtonOK (if it exists) will be run when the button is pressed.
Gui, Add, Button, yp+0 xp+100 gopen, &Open in browser  ; The label ButtonOK (if it exists) will be run when the button is pressed.
Gui Show, autosize Center, Delegate Voters List
Return

guidestroy:
Gui, Destroy
;Gui, Hide
return

savelist:
now := a_now
FileAppend %html_voters%, voter_list_%now%.html,UTF-8
Notify("File Saved","Voters are saved to voter_list" now ".html",popup_time,options)	
Return

open:
now := a_now
FileAppend %html_voters%, voter_list_%now%.html,UTF-8
run voter_list_%now%.html
Return

GETINFO:
info_message = Delegatename: %delegate_username%`nserver: %nodeurl%`nForging: %forgingstatus%`nAmount forged: %amount_forged% Lisk`nBlocks Forged: %delegate_producedblocks%`nMissed Blocks:%delegate_missedblocks%`nDelegate uptime: %delegate_productivity%`%`nDelegate Rank: #%delegate_rate%`nNumber of voters: %count_voters%`nTotal balance voted: %delegate_vote2% Lisk
notifyid := Notify("Delegate info (click to close)",info_message,100000000,notification_style)
return
;#####################################



createmenu:
;############### tray menu stuff ###########
Menu, tray, NoStandard

Menu, tray, add  ; Creates a separator line.
Menu, tray, add, Delegate Voters List, GETVOTES	; Creates a new menu item.
Menu, tray, add, Show Delegate Info, GETINFO ; Creates a new menu item.
Menu, tray, add  ; Creates a separator line.
Menu, tray, add, Pause Delegate Monitor, pause ; Creates a new menu item.
Menu, tray, add, Reload/Restart Delegate Monitor, reload ; Creates a new menu item.
Menu, tray, add
Menu, tray, add, Exit Delegate Monitor, onexit ; Creates a new menu item.
return




pause:
if A_IsPaused = 0
	Menu, tray, Rename, Pause Delegate Monitor,Continue Delegate Monitor
if A_IsPaused = 1
	Menu, tray, Rename, Continue Delegate Monitor, Pause Delegate Monitor
Pause Toggle	
return

reload:
Reload
return
;############### tray menu stuff - END ############




ONEXIT:
gosub SAVE_LOG
exitapp

SAVE_LOG:		; save log to file
if log=
	return
FileAppend %log%, log.csv
log:=""
return



;### this is the default content of the ini file. if not exist this will create it ###
createsettingsini:		; creates a settings ini file

defaultf =
(
/*
Notes: 
- if you make any changes to this file, you have to reload the script. Will automate later
- If you want the use the backup switch feature (switching nodes when there is a problem on the one you are forging on) you have to provide your account passphrase. This needs to be sent to the node to disable/enable forging remotely. This should only be done using SSL or your passhprase being transmited without encyption.
- You also have to put your IP into config.json, forging:whitelist, or have to be empty. If it's empty any active delegate can enable forging on your node.
*/

;########################################
;#####  Options that you must set  ######
;########################################
check_server_time := "30"	;in seconds. how often the script check your node for new data? If 0, there is no monitoring
nodeurl := ""			; domain or ip address with http(s) prefix - use https if you can! Add port if needed. e.g.: https://login.lisk.io or http://83.136.249.126:7000
delegatename := "" 	 ;	your delegate username

;### Only need to set these if you want to use switch to backup feature #######
switch_backup := "no"			; if yes it will switch forging to backup server
backupnodeurl := ""					; ip address for your backup server
delegatepass := "" 	; your delegte account passphrase. only needed for backup server failover

;########################################
;#####  Options that you may set   ######
;########################################

voterlist_getallusername := ""		; yes if you want the get every missing balance and username in voting list. voters list generation will be much slower

save_log := "yes"		; yes if you want the log file to be saved into file

notification_style := "GC=asdasd TC=White MC=White"		; you can change the notification popups design. for more see: http://www.gwarble.com/ahk/Notify/
popup_time := "20" 			; how many second a notifiation popup should be displayed

notifications := "yes"	
; if "yes" you get notifications about selected events (see Notification options)
;#########################################################
;#####  Notification options - what triggers popup  ######
;#########################################################

missedblock := "yes"			;if delegate missed a block
forged := "yes"				;if delegate forged a block
balanceincrease := "yes"		;if balance increased (excluding forge reward)
delegatevote := "yes"		;if someone voted/unvoded you
rankchange := "yes"			;if delegate rank changed
uptimedecrease := "yes"		;if delegate uptime decreased (problem indicator)


)
FileAppend %defaultf%, settings.ini
msgbox A default settings.ini was created. Please add your preferences to the ini file and start the script again.`n`nPress OK to exit the script.
exitapp



;#######################################################################

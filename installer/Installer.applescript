-- Installer app for Order of the Sinking Star on Apple Silicon Macs.
-- Runs the bundled install.sh in the background and mirrors its progress in a
-- progress window, so nobody needs Terminal. Built by make-installer-app.sh, which
-- copies install.sh and bundle/ into Contents/Resources/installer.

property gameName : "Order of the Sinking Star"
property windowTitle : "Install Order of the Sinking Star"
-- Empty means ~/Applications; make-installer-app.sh --test-dest sets it for test builds.
property destDir : ""

on run
	set installer to (POSIX path of (path to me)) & "Contents/Resources/installer/install.sh"
	set targetDir to destDir
	if targetDir is "" then set targetDir to (POSIX path of (path to home folder)) & "Applications"
	set targetApp to targetDir & "/" & gameName & ".app"
	set logPath to (POSIX path of (path to home folder)) & "Library/Logs/sinking-star-mac-install.log"

	if pathExists(targetApp) then
		set answer to button returned of (display dialog gameName & " is already installed." buttons {"Show in Finder", "OK"} default button "OK" with title windowTitle with icon note)
		if answer is "Show in Finder" then do shell script "open -R " & quoted form of targetApp
		return
	end if

	display dialog "This sets up " & gameName & " to run on your Mac, using the Windows version of Steam with Wine and Apple's D3DMetal." & return & return & ¬
		"It downloads about 500 MB and builds the app in your Applications folder. Then you sign in to Steam, which downloads the game (about 11 GB). You need to own the game on Steam." ¬
		buttons {"Cancel", "Install"} default button "Install" cancel button "Cancel" with title windowTitle

	-- Rosetta 2 runs the Windows (Intel) parts of the stack.
	if not succeeds("arch -x86_64 /usr/bin/true") then
		display dialog "The game also needs Rosetta 2, Apple's translator for Intel software. Install it now? macOS will ask for your password." ¬
			buttons {"Cancel", "Install Rosetta"} default button "Install Rosetta" cancel button "Cancel" with title windowTitle
		do shell script "/usr/sbin/softwareupdate --install-rosetta --agree-to-license" with administrator privileges
	end if

	set statusFile to do shell script "mktemp -t sinking-star-install"
	set pid to do shell script "/bin/zsh " & quoted form of installer & " --dest " & quoted form of targetDir & ¬
		" --status-file " & quoted form of statusFile & " >/dev/null 2>&1 & echo $!"

	set progress description to "Installing " & gameName
	set progress additional description to "Starting…"
	set progress total steps to 7
	set progress completed steps to 0
	try
		repeat
			delay 0.5
			-- Check liveness before reading, so a final line written just before exit is seen.
			set installerAlive to succeeds("kill -0 " & pid)
			set lastLine to do shell script "tail -n 1 " & quoted form of statusFile
			if lastLine starts with "done|" then exit repeat
			if lastLine starts with "error|" then error (text 7 thru -1 of lastLine) number 1000
			if lastLine starts with "step|" then
				set fields to splitText(lastLine, "|")
				set progress total steps to (item 3 of fields) as integer
				set progress completed steps to ((item 2 of fields) as integer) - 1
				set progress additional description to (item 4 of fields) & "…"
			end if
			if not installerAlive then error "The installer stopped unexpectedly. Details are in " & logPath number 1000
		end repeat
	on error msg number num
		-- Whatever ended the loop (Stop button, an install error, a bug here), make sure
		-- install.sh isn't left running unattended. It removes its partial app on the
		-- way out. Its child process goes first, since zsh only handles the signal once
		-- that returns.
		do shell script "pkill -TERM -P " & pid & "; kill " & pid & " 2>/dev/null; for i in $(seq 1 60); do kill -0 " & pid & " 2>/dev/null || break; sleep 0.5; done; true"
		if num is -128 then return
		set answer to button returned of (display dialog "The installation didn't finish:" & return & return & msg ¬
			buttons {"Show Log", "OK"} default button "OK" with title windowTitle with icon caution)
		if answer is "Show Log" then do shell script "open -e " & quoted form of logPath
		return
	end try

	set progress completed steps to progress total steps
	set progress additional description to "Done"
	set answer to button returned of (display dialog gameName & " is installed in your Applications folder." & return & return & ¬
		"Next, open it and sign in to Steam. Steam offers to install the game; when that's done, press Play. Later launches go straight into the game." & return & return & ¬
		"Tip: Settings > Resolution > 1440p is a good balance of sharpness and frame rate." ¬
		buttons {"Later", "Open Now"} default button "Open Now" with title windowTitle)
	if answer is "Open Now" then do shell script "open " & quoted form of targetApp
end run

on succeeds(shellCommand)
	try
		do shell script shellCommand
		return true
	on error
		return false
	end try
end succeeds

on pathExists(p)
	return succeeds("test -e " & quoted form of p)
end pathExists

on splitText(theText, delimiter)
	set saved to AppleScript's text item delimiters
	set AppleScript's text item delimiters to delimiter
	set parts to text items of theText
	set AppleScript's text item delimiters to saved
	return parts
end splitText

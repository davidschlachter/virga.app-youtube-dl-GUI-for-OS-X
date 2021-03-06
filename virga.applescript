## Folder for downloads inside your homedir (will be created if missing),
## Note trailing slash!
set downloadsFolder to "Downloads/"
set dnPwd to quoted form of (POSIX path of (path to home folder) & downloadsFolder)

## Explicit PATH declaration to assist locating youtube-dl, ffprobe, ffmpeg etc.
set shellPath to "PATH=$PATH:/bin:/sbin:/usr/bin:/usr/local/bin:/usr/sbin:~/opt/bin:~/opt/sbin:/opt/local/bin:/opt/local/sbin:" & quoted form of (POSIX path of ((path to me as text) & "::")) & "; "

## arguments and path for youtube-dl
set ytCmd to "youtube-dl"
set ytArgs to " --no-playlist --no-mtime "

## dialogs defaults
set optionList to {"MP3-audio only", "Video", "Video + audio"}
set extractAudio to ""
set playlistText1 to ""
set playlistText2 to ""
set playlistSize to 0
set ffMissing to "0"

try
	set ytMissing to do shell script shellPath & "command -v youtube-dl >/dev/null 2>&1"
	
on error errorMessage number errorNumber
	display dialog "youtube-dl not found.

To use virga.app, please install youtube-dl from http://yt-dl.org" with title "virga" with icon stop buttons {"Quit"} default button 1
	set answer to button returned of result
	if answer is equal to "Quit" then
		return -128
	end if
end try

## test if ffmpeg is present
try
	set ffMissing to do shell script shellPath & "command -v ffprobe >/dev/null 2>&1 ; echo $?"
end try

try
	## create downloads folder (if missing)
	do shell script "[ -d " & dnPwd & " ] || mkdir " & dnPwd
	
	## grab URL of the frontmost Chrome or Safari window/tab
	tell application "System Events" to set frontApp to name of first process whose frontmost is true
	
	if (frontApp = "Safari") or (frontApp = "Webkit") then
		using terms from application "Safari"
			tell application frontApp to set theURL to URL of front document
		end using terms from
	else if (frontApp = "Google Chrome") or (frontApp = "Google Chrome Canary") or (frontApp = "Chromium") then
		using terms from application "Google Chrome"
			tell application frontApp to set theURL to URL of active tab of front window
		end using terms from
	else
		tell application "Google Chrome"
			set theURL to URL of active tab of front window as string
		end tell
	end if
	
	## if URL is not recognized/supported, try updating youtube-dl
	set validURL to false
	repeat while not validURL
		display notification theURL with title "Checking URL (you can close tab now)" subtitle "download will start in background"
		
		try
			## get video filename for further checks
			set fileName to do shell script shellPath & ytCmd & ytArgs & " -o '%(title)s.%(ext)s' --get-filename --playlist-end 2 " & quoted form of theURL
			set validURL to true
			
		on error errorMessage number errorNumber
			if errorNumber is 1 then
				display dialog theURL & "

Media from this URL can't be downloaded or youtube-dl needs to be updated.

Would you like to update now? Admin password will be required." with icon caution with title "virga" buttons {"Update youtube-dl", "Quit"} default button 2
				set answer to button returned of result
				if answer is equal to "Quit" then
					return -128
				else if answer is equal to "Update youtube-dl" then
					try
						set updateResult to do shell script  shellPath &  ytCmd & " -U" with administrator privileges
						display alert updateResult buttons {"Retry media download"}
						
					on error errorMessage number errorNumber
						display dialog errorMessage with title "youtube-dl update FAILED" with icon stop buttons {"Quit"} default button 1
						set answer to button returned of result
						if answer is equal to "Quit" then
							return -128
						end if
					end try
				end if
			end if
		end try
	end repeat
	
	## do not ask download type for audio-files (soundcloud, mixcloud etc)
	set audioFile to do shell script "echo " & quoted form of fileName & " | grep -qEi '.(mp4|flv|wmv|mov|avi|mpeg|mpg|m4v|mkv|divx|asf|webm)$'; echo $?"
	set playlistSize to (count paragraphs in fileName)
	if audioFile is "0" then
		if ffMissing is "1" then
			display notification "You can get it from http://ffmpegmac.net/" with title "ffmpeg not found!" subtitle "It is required to extract audio from videofiles"
			display notification fileName with title "⬇️ Downloading media " subtitle "Check downloads folder for progress..."
		else if playlistSize > 1 then
			set playlistText1 to "playlist
"
			set playlistText2 to "
etc..."
			set answer to choose from list optionList with title "virga" cancel button name "Cancel" OK button name "Download" default items "Video" with prompt "Ready to download " & playlistText1 & fileName & playlistText2 & "

Please select download mode:"
			
			if answer is false then
				error number -128
			end if
		else
			display dialog "Ready to download
" & fileName & "

Please select download mode:" with title "virga" with icon (path to resource "applet.icns") buttons optionList default button 3
			set answer to button returned of result
		end if
		if answer is in {"MP3-audio only"} then
			set extractAudio to " --extract-audio --audio-format mp3 --audio-quality 0 "
			display notification fileName with title "🎶 Extracting audio " subtitle "Check downloads folder for progress..."
		else if answer is in {"Video + audio"} then
			set extractAudio to "  "
			display notification fileName with title "⬇️ Downloading video + audio " subtitle "Check downloads folder for progress..."
		else if answer is in {"Video"} then
			display notification fileName with title "⬇️ Downloading video " subtitle "Check downloads folder for progress..."
		end if
	else
		display notification fileName with title "⬇️ Downloading media " subtitle "Check downloads folder for progress..."
	end if
	
	try
		do shell script shellPath & "cd " & dnPwd & " && " & ytCmd & ytArgs & extractAudio & quoted form of theURL
		display notification fileName with title "✅ Finished downloading" subtitle " -> " & downloadsFolder sound name "Pop"
	on error errorMessage number errorNumber
		display notification errorMessage with title "❌ Download errors, see below" subtitle theURL sound name "Basso"
	end try
	
end try

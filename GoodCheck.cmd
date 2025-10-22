::by Ori
::todo translation
@echo off
chcp 1251
title GoodCheck
cls

SetLocal EnableDelayedExpansion


::==============================CONFIG================================
::General
set outputMostSuccessfulStrategiesSeparately=false

::Additional options
set "curlExtraKeys="
set "curlMinTimeout=2"

::TCP 16-20 detection options
set "tcp1620TimeoutMs=5000"
set "tcp1620OkThresholdBytes=65536"
set "tcp1620CustomId=CUST-01"
set "tcp1620CustomProvider=Custom"
set "tcp1620CustomUrl="
set "tcp1620CustomTimes=1"

::Folders and files
set "mostSuccessfulStrategiesFile=MostSuccessfulStrategies.txt"
set "strategiesFolder=Strategies"
set "curlFolder=Curl"
set "payloadsFolder=Payloads"
set "logsFolder=Logs"

::Strategy-related
set "fakeSNI=www.google.com"
set "fakeHexRaw=1603030135010001310303424143facf5c983ac8ff20b819cfd634cbf5143c0005b2b8b142a6cd335012c220008969b6b387683dedb4114d466ca90be3212b2bde0c4f56261a9801"
set "fakeHexBytes="
set "payloadTLS=tls_earth_google_com.bin"
set "payloadQuic=quic_ietf_www_google_com.bin"

::Web addresses for some functions
set "netConnTestURL=https://ya.ru"

::Testing program
:: Zapret
set "zapretName=Zapret"
set "zapretExeName=winws.exe"
set "zapretFolderOverride="
set "zapretServiceName=winws1"


::====================================================================
::Consts
set "version=v1.3.07"

set "goodCheckFolder=%~dp0"

(set nl=^
%emptyline%
)

set "choiceList=1 2 3 4 5 6 7 8 9 a b c d e f g h i j k l m n o p q r s t u v w x y z"

::Hashes for programs
:: Zapret last
set "hash_zapret_last=8c624e64742bc19447d52f61edec52db"


::====================================================================
::Turning letter lists into letter arrays for later
set choiceArrayLen=-1
for %%i in (!choiceList!) do (
	set /A choiceArrayLen+=1
	set choiceArray[!choiceArrayLen!]=%%i
)
::====================================================================
title GoodCheck !version!

::0 for no errors, 1 for minor errors, 2 for a critical error
set endedWithErrors=0

::Creating log
set "_time=%time:~0,-3%"
set "_time=!_time: =0!"
set "_time2=!_time::=-!"
set "_date=%date:.=-%"
set "_date=!_date:/=-!"
set "_date=!_date: =_!"

echo.
echo Creating log file...

set "logsFolder=!goodCheckFolder!!logsFolder!"
if not exist !logsFolder! (
	echo WARNING: Logs folder doesn't exist, creating...
	mkdir "!goodCheckFolder!Logs" >NUL
)

::Writing to log and handling errors
set "logFile=!logsFolder!\Log_GoodCheck_!_date!_!_time2!.txt"
echo GoodCheck !version! Log - !_date! - !_time!>"!logFile!"

if not exist "!logFile!" (
	set endedWithErrors=1
	echo WARNING: Problem encountered during logfile creation, attempting workaround...
	
	set "logFile=!goodCheckFolder!Log_%random%.txt"
	echo GoodCheck !version! Log - !_date! - !_time!>"!logFile!"
	
	if not exist "!logFile!" (
		set logFile=
		echo.
		echo WARNING: Can't create log file. Press any button to continue without one
		pause>NUL
	) else (
		echo Log file "!logFile!" successfully created
	)
) else (
	echo Log file "!logFile!" successfully created
)

call :WriteToConsoleAndToLog
call :WriteToConsoleAndToLog ---------------------
call :WriteToConsoleAndToLog


::====================================================================
::Taking variablies from env
call :WriteToConsoleAndToLog Reading external variables...

call :OverrideStringParam "!_zapretFolderOverride!" zapretFolderOverride

call :OverrideStringParam "!_fakeSNI!" fakeSNI
call :OverrideStringParam "!_fakeHexRaw!" fakeHexRaw
call :OverrideStringParam "!_fakeHexBytes!" fakeHexBytes
call :OverrideStringParam "!_payloadTLS!" payloadTLS
call :OverrideStringParam "!_payloadQuic!" payloadQuic

call :OverrideStringParam "!_curlMinTimeout!" curlMinTimeout
call :OverrideStringParam "!_curlExtraKeys!" curlExtraKeys

call :OverrideStringParam "!_tcp1620TimeoutMs!" tcp1620TimeoutMs
call :OverrideStringParam "!_tcp1620OkThresholdBytes!" tcp1620OkThresholdBytes
call :OverrideStringParam "!_tcp1620CustomId!" tcp1620CustomId
call :OverrideStringParam "!_tcp1620CustomProvider!" tcp1620CustomProvider
call :OverrideStringParam "!_tcp1620CustomUrl!" tcp1620CustomUrl
call :OverrideStringParam "!_tcp1620CustomTimes!" tcp1620CustomTimes

call :OverrideBooleanParam "!_outputMostSuccessfulStrategiesSeparately!" outputMostSuccessfulStrategiesSeparately
call :OverrideStringParam "!_mostSuccessfulStrategiesFile!" mostSuccessfulStrategiesFile

call :WriteToConsoleAndToLog
call :WriteToConsoleAndToLog ---------------------
call :WriteToConsoleAndToLog


::====================================================================
::Initial checks
call :WriteToConsoleAndToLog Initial Checks...

::Winver
for /f "tokens=4 delims=. " %%i in ('ver') do (set "winVersion=%%i")
call :WriteToConsoleAndToLog Windows major version: !winVersion!

::Checking up if we have admin rights
call :WriteToConsoleAndToLog Checking privilegies...
::Net session method not working for some people
rem net session >NUL 2>&1
fsutil dirty query %systemdrive% >NUL
if not !ERRORLEVEL!==0 (
	set endedWithErrors=2
	call :WriteToConsoleAndToLog
	call :WriteToConsoleAndToLog ERROR: This script requires elevated privilegies
	call :WriteToConsoleAndToLog
	call :WriteToConsoleAndToLog You need to right click on "%~n0%~x0" and choose "Run as administrator"
	goto EOF
)

::Checking up that checklist folder do exist
call :WriteToConsoleAndToLog Checking up if checklists folder do exist...
set "checkListFolder=!goodCheckFolder!!checkListFolder!\"
if not exist "!checkListFolder!" (
	set endedWithErrors=2
	call :WriteToConsoleAndToLog
	call :WriteToConsoleAndToLog ERROR: Can't find checklists folder
	goto EOF
)

::Checking up that strategies folder do exist
call :WriteToConsoleAndToLog Checking up if strategies folder do exist...
set "strategiesFolder=!goodCheckFolder!!strategiesFolder!\"
if not exist "!strategiesFolder!" (
	set endedWithErrors=2
	call :WriteToConsoleAndToLog
	call :WriteToConsoleAndToLog ERROR: Can't find strategies folder
	goto EOF
)

::Checking up that payloads folder do exist
call :WriteToConsoleAndToLog Checking up if payloads folder do exist...
set "payloadsFolder=!goodCheckFolder!!payloadsFolder!\"
if not exist "!payloadsFolder!" (
	set endedWithErrors=1
	call :WriteToConsoleAndToLog WARNING: Can't find payloads folder, continuing anyway...
) else (
	set payloadQuic="!payloadsFolder!!payloadQuic!"
	set payloadTLS="!payloadsFolder!!payloadTLS!"
)

::Setting subfolder based on processor architecture for future use
set "processorSubFolder=x86"
if "%PROCESSOR_ARCHITECTURE%"=="AMD64" (set "processorSubFolder=x86_64")
if defined PROCESSOR_ARCHITEW6432 (set "processorSubFolder=x86_64")

::Checking up that curl do exist
call :WriteToConsoleAndToLog Checking up if Curl do exist...
if defined curlFolder (
	set "curl=!goodCheckFolder!!curlFolder!\!processorSubFolder!\curl.exe"
        if not exist "!curl!" (
                call :WriteToConsoleAndToLog WARNING: Can't find Curl in it's folder...
                set "curl=!goodCheckFolder!curl.exe"
        )
)
if not exist "!curl!" (
	call :WriteToConsoleAndToLog WARNING: Can't find Curl in script folder...
	set "curl=curl.exe"
)
"!curl!" -V >NUL
if not !ERRORLEVEL!==0 (
	set endedWithErrors=2
	call :WriteToConsoleAndToLog
	call :WriteToConsoleAndToLog ERROR: Can't find Curl
	call :WriteToConsoleAndToLog
	call :WriteToConsoleAndToLog Download it at https://curl.se/ and put the content of /bin/ folder next to this script
	goto EOF
) else (
	call :WriteToConsoleAndToLog -----
	for /F "usebackq tokens=* delims=" %%i in (`"!curl!" -V`) do (call :WriteToConsoleAndToLog %%i)
	call :WriteToConsoleAndToLog -----
)

::Checking up network connectivity
call :WriteToConsoleAndToLog Checking up network connectivity...
::Apparently ICMP is blocked for some people, so we'll use curl here
rem ping -n 1 -w 2000 "!netConnTestURL!">NUL
"!curl!" -m !curlMinTimeout! -so NUL "!netConnTestURL!"
if not !ERRORLEVEL!==0 (
	call :WriteToConsoleAndToLog WARNING: Basic connectivity test failed, attempting insecure...
	"!curl!" -m !curlMinTimeout! --insecure -so NUL "!netConnTestURL!"
	if not !ERRORLEVEL!==0 (
		set endedWithErrors=2
		call :WriteToConsoleAndToLog
		call :WriteToConsoleAndToLog ERROR: No network connection. Make sure Curl aren't blocked by your firewall.
		goto EOF
	) else (
		set endedWithErrors=1
		set "curlExtraKeys=!curlExtraKeys! --insecure"
		call :WriteToConsoleAndToLog
		call :WriteToConsoleAndToLog WARNING: Network connection is present, but certificate verification is failed
		call :WriteToConsoleAndToLog
		call :WriteToConsoleAndToLog Either your firewall or antivirus are affecting connections, or ca-bundle is corrupted/unaccessible
		call :WriteToConsoleAndToLog
		echo Press any button to continue without certificate verifications...
		pause>NUL
	)
)

::Looking for executables
call :WriteToConsoleAndToLog Looking for executables...
::...for Zapret
if defined zapretFolderOverride (
        call :LookForExe "!zapretExeName!" "!zapretFolderOverride!" "!zapretName!" zapretExeFullpath
)
if not defined zapretExeFullpath (
	call :LookForExe "zapret-winws\!zapretExeName!" "!zapretFolderOverride!" "!zapretName!" zapretExeFullpath
)
if not defined zapretExeFullpath (
	call :LookForExe "!zapretExeName!" "!goodCheckFolder!" "!zapretName!" zapretExeFullpath
)
if not defined zapretExeFullpath (
	call :WriteToConsoleAndToLog Can't find "!zapretName!" anywhere...
) else (
        ::...Checking if it's outdated
        call :CalculateHash "!zapretExeFullpath!" hash
        set confirmed=
        if "!winVersion!"=="10" (
		if !hash!==!hash_zapret_last! (
			call :WriteToConsoleAndToLog You're using the last version of "!zapretName!"
			set "zapretVersion=(last official build detected)"
			set confirmed=1
		)
		if not defined confirmed (
			call :WriteToConsoleAndToLog You're using either an outdated or unknown version of "!zapretName!" - it can cause problems
			set "zapretVersion=(unknown or outdated version)"
		)
	)
)

call :WriteToConsoleAndToLog
call :WriteToConsoleAndToLog ---------------------
call :WriteToConsoleAndToLog


::====================================================================
::User choosing a test provider here
call :WriteToLog Script is ready.
:CHOICELOOP
cls

echo.
echo "!zapretName!" will be closed.
echo Its services will be stopped and removed.
echo.
echo.
echo Choose a program to test with:
echo.

set choiceTest=
if defined zapretExeFullpath (
        echo Press [1] - test with "!zapretName!" !zapretVersion!
        set choiceTest=!choiceTest!1
) else (
        echo -
        set choiceTest=!choiceTest!A
)
set choiceTest=!choiceTest!0
echo.
echo Press [0] - cancel and exit

choice /C !choiceTest! /CS >NUL
set testWith=!ERRORLEVEL!

if !testWith!==2 (
        call :WriteToConsoleAndToLog
        call :WriteToConsoleAndToLog Cancelling...
        goto EOF
)

echo.
echo -
echo.

if !testWith!==1 (
        call :UserInputSubchoice "!zapretName!" strategiesList
        if not "!strategiesList!"=="-1" (
                set "exeName=!zapretExeName!"
                set "serviceName=!zapretServiceName!"
                set "exeFullpath=!zapretExeFullpath!"
                set "programName=!zapretName!"
        ) else (
                goto CHOICELOOP
        )
)

call :WriteToConsoleAndToLog
call :WriteToConsoleAndToLog Proceeding with "!programName!" and "!strategiesList!" strategy list...

call :WriteToConsoleAndToLog
call :WriteToConsoleAndToLog -------------------------------
call :WriteToConsoleAndToLog


::====================================================================
::Converting strategies list into an array
call :WriteToConsoleAndToLog Parsing strategy list...
call :WriteToConsoleAndToLog

set strategiesNum=-3
for /F "usebackq tokens=* eol=/" %%i in ("!strategiesList!") do (
	set /A strategiesNum+=1
	if !strategiesNum! LSS 0 (
		for /F "tokens=1,2* delims=#" %%j in ("%%i") do (
			if "%%j"=="_strategyCurlExtraKeys" (
				call :WriteToConsoleAndToLog Curl extra keys found: %%k
				set "curlExtraKeys=!curlExtraKeys! %%k"
			)
			if "%%j"=="_strategyExtraKeys" (
				call :WriteToConsoleAndToLog Strategy extra keys found: %%k
				call :WriteToConsoleAndToLog
				set "strategyExtraKeys=%%k"
			)
		)
	)
	if !strategiesNum! GEQ 0 (
		call :FormatStrategy "%%i" "!programName!" strategy
		call :WriteToConsoleAndToLog Reading strategies ^(!strategiesNum!^): !strategy!
		set "strategiesArray[!strategiesNum!]=!strategy!"
	)
)

call :WriteToConsoleAndToLog
call :WriteToConsoleAndToLog -------------------------------
call :WriteToConsoleAndToLog


::====================================================================
::Preparing TCP 16-20 DPI detection test suite
cls

echo.
echo "!zapretName!" will be closed.
echo Its services will be stopped and removed.
echo.
echo.
echo Preparing TCP 16-20 DPI detection checks...
echo.
echo Press [4] to continue
echo Press [0] to exit

choice /c 40 /CS >NUL
set _choice=!ERRORLEVEL!
if !_choice!==2 (
        call :WriteToConsoleAndToLog
        call :WriteToConsoleAndToLog Cancelling...
        goto EOF
)

::Normalizing TCP 16-20 settings
if not defined tcp1620TimeoutMs (set "tcp1620TimeoutMs=5000")
for /F "delims=0123456789" %%i in ("!tcp1620TimeoutMs!") do (set "tcp1620TimeoutMs=5000")
if not defined tcp1620OkThresholdBytes (set "tcp1620OkThresholdBytes=65536")
for /F "delims=0123456789" %%i in ("!tcp1620OkThresholdBytes!") do (set "tcp1620OkThresholdBytes=65536")
if not defined tcp1620CustomTimes (set "tcp1620CustomTimes=1")
for /F "delims=0123456789" %%i in ("!tcp1620CustomTimes!") do (set "tcp1620CustomTimes=1")

set /A tcp1620TimeoutSec=(tcp1620TimeoutMs+999)/1000
if !tcp1620TimeoutSec! LEQ 0 (set tcp1620TimeoutSec=1)
set /A tcp1620CustomTimes+=0
if !tcp1620CustomTimes! LEQ 0 (set tcp1620CustomTimes=1)

call :WriteToConsoleAndToLog Preparing TCP 16-20 DPI detection test suite...
call :WriteToConsoleAndToLog

set testCaseIndex=-1
call :AddTcp1620Test "CF-01" "Cloudflare" "https://cdn.cookielaw.org/scripttemplates/202501.2.0/otBannerSdk.js" "1"
call :AddTcp1620Test "CF-02" "Cloudflare" "https://genshin.jmp.blue/characters/all#" "1"
call :AddTcp1620Test "CF-03" "Cloudflare" "https://api.frankfurter.dev/v1/2000-01-01..2002-12-31" "1"
call :AddTcp1620Test "DO-01" "DigitalOcean" "https://genderize.io/" "1"
call :AddTcp1620Test "HE-01" "Hetzner" "https://bible-api.com/john+1,2,3,4,5,6,7,8,9,10" "1"
call :AddTcp1620Test "HE-02" "Hetzner" "https://tcp1620-01.dubybot.live/1MB.bin" "1"
call :AddTcp1620Test "HE-03" "Hetzner" "https://tcp1620-02.dubybot.live/1MB.bin" "1"
call :AddTcp1620Test "HE-04" "Hetzner" "https://tcp1620-05.dubybot.live/1MB.bin" "1"
call :AddTcp1620Test "HE-05" "Hetzner" "https://tcp1620-06.dubybot.live/1MB.bin" "1"
call :AddTcp1620Test "OVH-01" "OVH" "https://eu.api.ovh.com/console/rapidoc-min.js" "1"
call :AddTcp1620Test "OVH-02" "OVH" "https://ovh.sfx.ovh/10M.bin" "1"
call :AddTcp1620Test "OR-01" "Oracle" "https://oracle.sfx.ovh/10M.bin" "1"
call :AddTcp1620Test "AWS-01" "AWS" "https://tms.delta.com/delta/dl_anderson/Bootstrap.js" "1"
call :AddTcp1620Test "AWS-02" "AWS" "https://corp.kaltura.com/wp-content/cache/min/1/wp-content/themes/airfleet/dist/styles/theme.css" "1"
call :AddTcp1620Test "FST-01" "Fastly" "https://www.juniper.net/content/dam/www/assets/images/diy/DIY_th.jpg/jcr:content/renditions/600x600.jpeg" "1"
call :AddTcp1620Test "FST-02" "Fastly" "https://www.graco.com/etc.clientlibs/clientlib-site/resources/fonts/lato/Lato-Regular.woff2" "1"
call :AddTcp1620Test "AKM-01" "Akamai" "https://www.lg.com/lg5-common-gp/library/jquery.min.js" "1"
call :AddTcp1620Test "AKM-02" "Akamai" "https://media-assets.stryker.com/is/image/stryker/gateway_1?$max_width_1410$" "1"

if defined tcp1620CustomUrl (
        call :AddTcp1620Test "!tcp1620CustomId!" "!tcp1620CustomProvider!" "!tcp1620CustomUrl!" "!tcp1620CustomTimes!"
)

set /A curlThreadsNum=0
for /L %%i in (0,1,!testCaseIndex!) do (
        set "tcpTimes=!testTimes[%%i]!"
        if not defined tcpTimes (set "tcpTimes=1")
        set /A curlThreadsNum+=tcpTimes
        set "timesLabel="
        if !tcpTimes! GTR 1 (set "timesLabel= (x!tcpTimes!)")
        call :WriteToConsoleAndToLog Test: !testId[%%i]! (!testProvider[%%i]!) - !testUrl[%%i]!!timesLabel!
)

if  !curlThreadsNum!==0 (
        set endedWithErrors=2
        call :WriteToConsoleAndToLog
        call :WriteToConsoleAndToLog ERROR: Nothing to check
        goto EOF
)

set /A curlParallelRequestTimeout=tcp1620TimeoutSec
if !curlParallelRequestTimeout! LEQ 0 (set curlParallelRequestTimeout=1)

call :WriteToConsoleAndToLog
call :WriteToConsoleAndToLog Total: !curlThreadsNum! tests     Timeout per test: !tcp1620TimeoutMs! ms ^(~!curlParallelRequestTimeout! s^)     Threshold: !tcp1620OkThresholdBytes! bytes
call :WriteToConsoleAndToLog

::====================================================================
::Choosing how many passes to do
set /A "_strategiesNum=!strategiesNum!+1"
set numberOfPasses=1

:USERCHOICENUMBEROFPASSES
cls

set /A "estimatedRawSeconds=!numberOfPasses!*!_strategiesNum!*(!curlThreadsNum!*!curlParallelRequestTimeout!+1)"
call :SecondsToMinutesSeconds !estimatedRawSeconds! estimatedMinutes estimatedSeconds

echo.
echo "!zapretName!" will be closed.
echo Its services will be stopped and removed.
echo.
echo.
echo Estimated time for a test: !estimatedMinutes! minutes !estimatedSeconds! seconds
echo.
echo.
echo Choose how many passes to do: !numberOfPasses!
echo.
echo Press [1] - increase
echo Press [2] - decrease
echo.
echo Press [4] - accept
echo.
echo Press [0] - exit

::Using lifehack, don't press shift+F at runtime
set choises=1240
if !numberOfPasses!==1 (set "choises=1F40")
if !numberOfPasses!==9 (set "choises=F240")

choice /c !choises! /CS >NUL

set _choice=!ERRORLEVEL!

if !_choice!==1 (
	set /A numberOfPasses+=1
	goto USERCHOICENUMBEROFPASSES
)
if !_choice!==2 (
	set /A numberOfPasses-=1
	goto USERCHOICENUMBEROFPASSES
)
if !_choice!==3 (
	call :WriteToConsoleAndToLog
	call :WriteToConsoleAndToLog Proceeding with !numberOfPasses! passes...
)
if !_choice!==4 (
	call :WriteToConsoleAndToLog
	call :WriteToConsoleAndToLog Cancelling...
	goto EOF
)


call :WriteToLog Estimated time for a test: !estimatedMinutes! minutes !estimatedSeconds! seconds

call :WriteToConsoleAndToLog
call :WriteToConsoleAndToLog -------------------------------
call :WriteToConsoleAndToLog


::====================================================================
call :WriteToConsoleAndToLog Terminating active programs and services...

call :PurgeProgram "!zapretExeName!"
call :PurgeService "!zapretServiceName!"

call :PurgeWinDivert

call :WriteToConsoleAndToLog
call :WriteToConsoleAndToLog -------------------------------
call :WriteToConsoleAndToLog


::====================================================================
::Main testing loop
cls
echo.

::Time estimation
set /A "_oneCycleTime=!curlThreadsNum!*!curlParallelRequestTimeout!+1"
set /A "estimatedRawSeconds=!numberOfPasses!*!_strategiesNum!*!_oneCycleTime!"
call :SecondsToMinutesSeconds !estimatedRawSeconds! estimatedMinutes estimatedSeconds

for /L %%i in (0,1,!strategiesNum!) do (

	call :WriteToConsoleAndToLog Testing ^(%%i/!strategiesNum!^): !strategiesArray[%%i]!
	
	REM echo curl !curlExtraKeys! -sm !curlParallelRequestTimeout! -w "%%{url}$%%{response_code} " -Z --parallel-immediate --parallel-max 300 !curlURL!
	REM pause
	
	call :WriteToConsoleAndToLog Starting up !programName!...
	start "!programName! - Launched through GoodCheck - Strategy %%i out of !strategiesNum!" /min "!exeFullpath!" !strategiesArray[%%i]!

	::Making request to see if servers are reachable. Timeout is neccessary to give program some time to load. Default timeout command is unreleable, using lifehack
	timeout /T 1 >NUL
	rem choice /C Q /D Q /CS /T 1 >NUL
	
        set lowestSuccesses=0
        set "lowestSummary="
	for /L %%z in (1,1,!numberOfPasses!) do (
		
		title GoodCheck !version! - Testing in progress: %%i out of !strategiesNum! - Time remaining: !estimatedMinutes! minutes !estimatedSeconds! seconds
		
		::Time estimation
		set /A "estimatedRawSeconds=!estimatedRawSeconds!-!_oneCycleTime!"
		call :SecondsToMinutesSeconds !estimatedRawSeconds! estimatedMinutes estimatedSeconds
	
		call :RunTcp1620Suite passSuccesses
		set successes=!passSuccesses!

		if "!lowestSuccesses!"=="0" (
			set lowestSuccesses=!successes!
			set "lowestSummary=!tcp1620LastSummary!"
		) else (
			if !successes! LSS !lowestSuccesses! (
				set lowestSuccesses=!successes!
				set "lowestSummary=!tcp1620LastSummary!"
			)
		)

		call :WriteToConsoleAndToLog Successes - Pass %%z: !successes!/!curlThreadsNum! ^(!tcp1620LastSummary!^)
		call :WriteToConsoleAndToLog
	)	
		
	::Writing to a variable for future use
        if not defined lowestSummary (set "lowestSummary=No summary")
        set "resultsArray[%%i]=!lowestSuccesses!/!strategiesArray[%%i]! - !lowestSummary!"
        set "successesExist[!lowestSuccesses!]=1"
	
	call :WriteToConsoleAndToLog Terminating !programName!...
	call :PurgeProgram "!exeName!"
	rem call :PurgeService "!serviceName!"
	rem call :PurgeWinDivert
)

title GoodCheck !version! - Completed

call :WriteToConsoleAndToLog
call :WriteToConsoleAndToLog -------------------------------
call :WriteToConsoleAndToLog


::====================================================================
::Showcasing results and writing it to a file
set mostSuccessfulStrategies=0
for /L %%i in (0,1,!curlThreadsNum!) do (
	if defined successesExist[%%i] (
		call :WriteToConsoleAndToLog Strategies with %%i out of !curlThreadsNum! successes:
		for /L %%j in (0,1,!strategiesNum!) do (
			for /F "tokens=1,2 delims=/" %%k in ("!resultsArray[%%j]!") do (
				if "%%k"=="%%i" (
					if "!outputMostSuccessfulStrategiesSeparately!"=="true" (
						set mostSuccessfulStrategies=%%i
					)
					call :WriteToConsoleAndToLog %%l
				)
			)
		)
		call :WriteToConsoleAndToLog
	)
)
::Output most successful strategies separately
if "!outputMostSuccessfulStrategiesSeparately!"=="true" (
	if not defined _mostSuccessfulStrategiesFile (
		for /F "tokens=1,2 delims=." %%p in ("!mostSuccessfulStrategiesFile!") do (
			set "mostSuccessfulStrategiesFile=%%p_!programName!.%%q"
		)
	)

	if exist "!mostSuccessfulStrategiesFile!" (
		del "!mostSuccessfulStrategiesFile!"
	)
	
	for /L %%j in (0,1,!strategiesNum!) do (
		for /F "tokens=1,2 delims=/" %%k in ("!resultsArray[%%j]!") do (
			if "%%k"=="!mostSuccessfulStrategies!" (
				echo %%l>>"!mostSuccessfulStrategiesFile!"
			)
		)
	)
)

call :WriteToConsoleAndToLog -------------------------------
call :WriteToConsoleAndToLog

echo -------------------------------
echo.
echo Log saved to "!logFile!"
if "!outputMostSuccessfulStrategiesSeparately!"=="true" (
	echo.
	echo Most successful strategies saved to "!mostSuccessfulStrategiesFile!"
)
echo.

call :WriteToConsoleAndToLog -------------------------------

goto EOF


::====================================================================

:PurgeProgram
SetLocal EnableDelayedExpansion
set "taskName=%~1"
taskkill /T /F /IM "!taskName!" >NUL 2>&1
EndLocal
exit /b

:PurgeService
SetLocal EnableDelayedExpansion
set "serviceName=%~1"
net stop "!serviceName!" >NUL 2>&1
sc delete "!serviceName!" >NUL 2>&1
EndLocal
exit /b

:PurgeWinDivert
net stop "WinDivert" >NUL 2>&1
sc delete "WinDivert" >NUL 2>&1
net stop "WinDivert14" >NUL 2>&1
sc delete "WinDivert14" >NUL 2>&1
exit /b

:WriteToConsoleAndToLog
SetLocal EnableDelayedExpansion
set "message=%*"
if "!message!"=="" (
	echo.
	if defined logFile (
		echo.>>"!logFile!"
	)
) else (
	echo !message!
	if defined logFile (
		echo !message!>>"!logFile!"
	)
)
EndLocal
exit /b

:WriteToLog
SetLocal EnableDelayedExpansion
set "message=%*"
if "!message!"=="" (
	if defined logFile (
		echo.>>"!logFile!"
	)
) else (
	if defined logFile (
		echo !message!>>"!logFile!"
	)
)
EndLocal
exit /b


:LookForExe
SetLocal EnableDelayedExpansion
set "exe=%~1"
set "path=%~2"
set "name=%~3"
set "fullpath=!path!!exe!"
if exist "!fullpath!" (
	call :WriteToConsoleAndToLog "!name!" is found at "!fullpath!"
) else (
	REM echo !name! NOT found at !fullpath!
	set "fullpath=!path!\!exe!"
	if exist "!fullpath!" (
		call :WriteToConsoleAndToLog "!name!" is found at "!fullpath!"
	) else (
		REM echo !name! NOT found at !fullpath!
		set fullpath=
	)
)
EndLocal && (set "%~4=%fullpath%")
exit /b


:FormatStrategy
SetLocal EnableDelayedExpansion
set "strategy=%~1"
set "program=%~2"
set "strategy=!strategyExtraKeys! !strategy!"
::mode for Zapret
if "!program!"=="!zapretName!" (
        set "strategy=!strategy:PAYLOADTLS=%payloadTLS%!"
        set "strategy=!strategy:PAYLOADQUIC=%payloadQuic%!"
)
EndLocal && (set "%~3=%strategy%")
exit /b

:AddTcp1620Test
set "testTimesValue=%~4"
if not defined testTimesValue (set "testTimesValue=1")
set /A testCaseIndex+=1
set "testId[!testCaseIndex!]=%~1"
set "testProvider[!testCaseIndex!]=%~2"
set "testUrl[!testCaseIndex!]=%~3"
set "testTimes[!testCaseIndex!]=!testTimesValue!"
set "testTimesValue="
exit /b

:AppendUniqueQuery
SetLocal EnableDelayedExpansion
set "base=%~1"
for /F "tokens=1* delims=#" %%a in ("!base!") do (
        set "base=%%a"
)
set "marker=?"
if not "!base!"=="!base:?=!" (set "marker=&")
set "randomValue=%random%%random%%random%"
set "unique=!base!!marker!t=!randomValue!"
EndLocal && (set "%~2=%unique%")
exit /b

:RunSingleTcp1620Test
SetLocal EnableDelayedExpansion
set "testId=%~1"
set "testProvider=%~2"
set "testUrl=%~3"
set "iteration=%~4"
set "iterationTotal=%~5"
call :AppendUniqueQuery "!testUrl!" uniqueUrl
set "targetUrl=!uniqueUrl!"
set "curlMeta="
set "curlErrorLine="
set "writeOut=HTTP_CODE=%%{http_code};SIZE=%%{size_download};IP=%%{remote_ip};ERR=%%{errormsg}"
for /F "usebackq delims=" %%O in (`"!curl!" !curlExtraKeys! --silent --show-error --no-progress-meter --max-time !tcp1620TimeoutSec! --connect-timeout !tcp1620TimeoutSec! --range 0-65535 --output NUL --write-out "!writeOut!" "!targetUrl!" 2^>^&1`) do (
        set "line=%%O"
        if not defined curlMeta (
                if not "!line:HTTP_CODE=!=!line!" (
                        set "curlMeta=!line!"
                ) else (
                        if not defined curlErrorLine (set "curlErrorLine=!line!")
                )
        ) else (
                if not "!line:HTTP_CODE=!=!line!" (
                        set "curlMeta=!line!"
                )
        )
)
set "curlExit=!ERRORLEVEL!"
set "httpCode=000"
set "downloadSize=0"
set "remoteIp="
set "errorMessage="
if defined curlMeta (
        for /F "tokens=1-4 delims=;" %%A in ("!curlMeta!") do (
                for /F "tokens=2 delims==" %%p in ("%%A") do set "httpCode=%%p"
                for /F "tokens=2 delims==" %%p in ("%%B") do set "downloadSize=%%p"
                for /F "tokens=2 delims==" %%p in ("%%C") do set "remoteIp=%%p"
                for /F "tokens=2 delims==" %%p in ("%%D") do set "errorMessage=%%p"
        )
)
if not defined errorMessage if defined curlErrorLine set "errorMessage=!curlErrorLine!"
for /F "tokens=1 delims=." %%p in ("!downloadSize!") do set "downloadSize=%%p"
if not defined downloadSize set "downloadSize=0"
set "statusShort=FAIL"
set "statusText=Failed to complete ⚠️"
if "!curlExit!"=="0" (
        if !downloadSize! GEQ !tcp1620OkThresholdBytes! (
                set "statusShort=OK"
                set "statusText=Not detected ✅"
        ) else (
                set "statusShort=WARN"
                set "statusText=Possibly detected ⚠️"
        )
) else if "!curlExit!"=="28" (
        set "statusShort=DETECTED"
        if "!httpCode!"=="000" (
                set "statusText=Detected*❗️"
        ) else (
                set "statusText=Detected❗️"
        )
) else (
        set "statusShort=FAIL"
        set "statusText=Failed to complete ⚠️"
)
EndLocal && (
        set "tcp1620Status=%statusText%"
        set "tcp1620StatusShort=%statusShort%"
        set "tcp1620HttpCode=%httpCode%"
        set "tcp1620Bytes=%downloadSize%"
        set "tcp1620ExitCode=%curlExit%"
        set "tcp1620RemoteIp=%remoteIp%"
        set "tcp1620Error=%errorMessage%"
)
exit /b

:RunTcp1620Suite
SetLocal EnableDelayedExpansion
set successes=0
set warnCount=0
set detectedCount=0
set failCount=0
for /L %%t in (0,1,!testCaseIndex!) do (
        set "caseId=!testId[%%t]!"
        set "caseProvider=!testProvider[%%t]!"
        set "caseUrl=!testUrl[%%t]!"
        set "caseTimes=!testTimes[%%t]!"
        if not defined caseTimes (set "caseTimes=1")
        for /L %%x in (1,1,!caseTimes!) do (
                call :RunSingleTcp1620Test "!caseId!" "!caseProvider!" "!caseUrl!" "%%x" "!caseTimes!"
                set "label=!caseId!"
                if !caseTimes! GTR 1 (set "label=!caseId!-%%x")
                set "details=HTTP !tcp1620HttpCode!, bytes !tcp1620Bytes!, exit !tcp1620ExitCode!"
                if defined tcp1620RemoteIp (set "details=!details!, ip !tcp1620RemoteIp!")
                if defined tcp1620Error if not "!tcp1620Error!"=="" (set "details=!details!, err !tcp1620Error!")
                call :WriteToConsoleAndToLog [!label!] !caseProvider!: !tcp1620Status! (!details!)
                if /I "!tcp1620StatusShort!"=="OK" (
                        set /A successes+=1
                ) else if /I "!tcp1620StatusShort!"=="WARN" (
                        set /A warnCount+=1
                ) else if /I "!tcp1620StatusShort!"=="DETECTED" (
                        set /A detectedCount+=1
                ) else (
                        set /A failCount+=1
                )
        )
)
set "summary=OK: !successes!, WARN: !warnCount!, Detected: !detectedCount!, Failed: !failCount!"
EndLocal && (
        set "%~1=%successes%"
        set "tcp1620LastSummary=%summary%"
)
exit /b

:CalculateHash
SetLocal EnableDelayedExpansion
set "file=%~1"
set count=0
set hash=0
for /F %%i in ('certutil -hashfile "!file!" MD5') do (
	set /A count+=1
	if !count!==2 (set hash=%%i)
)
EndLocal && (set "%~2=%hash%")
exit /b

:OverrideStringParam
SetLocal EnableDelayedExpansion
set "externalParam=%~1"
if defined externalParam (
	set "override=!externalParam!"
)
EndLocal && (
	if not "%override%"=="" (
		set "%~2=%override%"
	)
)
exit /b

:OverrideBooleanParam
SetLocal EnableDelayedExpansion
set "externalParam=%~1"
if defined externalParam (
	set "externalParam=!externalParam:T=t!"
	set "externalParam=!externalParam:R=r!"
	set "externalParam=!externalParam:U=u!"
	set "externalParam=!externalParam:E=e!"
	set "externalParam=!externalParam:F=f!"
	set "externalParam=!externalParam:A=a!"
	set "externalParam=!externalParam:L=l!"
	set "externalParam=!externalParam:S=s!"
	if not "!externalParam!"=="true" (
		if not "!externalParam!"=="false" (
			set endedWithErrors=1
			call :WriteToConsoleAndToLog WARNING: Can't override variable. Value "!externalParam!" is unacceptable.
		) else (
			set "override=!externalParam!"
		)
	) else (
		set "override=!externalParam!"
	)
)
EndLocal && (
	if not "%override%"=="" (
		set "%~2=%override%"
	)
)
exit /b

:SecondsToMinutesSeconds
SetLocal EnableDelayedExpansion
set "rawSeconds=%~1"
set /A minutes=!rawSeconds!/60
set /A seconds=!rawSeconds!-(!minutes!*60)
EndLocal && (
	set "%~2=%minutes%"
	set "%~3=%seconds%"
)
exit /b

:UserInputSubchoice
SetLocal EnableDelayedExpansion
set "strategiesSubfolder=%~1"
set count=0

pushd "!strategiesFolder!"
if exist "!strategiesSubfolder!" (
	pushd "!strategiesSubfolder!"
	for /F "usebackq delims=" %%i in (`dir /b /o:n`) do (
		if !count! LEQ !choiceArrayLen! (
			call set letter=%%choiceArray[!count!]%%
			set /A count+=1
			set "strategy[!count!]=%%~fi"
			echo Press [!letter!] - %%i
			set subChoice=!subChoice!!letter!
		)
	)
	if !count!==0 (
		echo No strategy list found for "!strategiesSubfolder!"
	)
	popd
) else (
	echo Subfolder for "!strategiesSubfolder!" not found
)
set /A count+=1
set subChoice=!subChoice!0
echo.
echo Press [0] - Back

choice /C !subChoice! >NUL
set userChoice=!ERRORLEVEL!
if !userChoice!==!count! (
	set finalList=-1
) else (
	set /A count-=1
	for /L %%i in (1,1,!count!) do (
		if %%i==!userChoice! (set "finalList=!strategy[%%i]!")
	)
)

popd
Endlocal && (set "%~2=%finalList%")
exit /b

)

set /A count+=1
set checkListChoice=!checkListChoice!0
echo.
echo Press [0] - cancel and exit

choice /C !checkListChoice! >NUL
set userChoice=!ERRORLEVEL!
if !userChoice!==!count! (
	set choosedList=-1
) else (
	set /A count-=1
	for /L %%i in (1,1,!count!) do (
		if %%i==!userChoice! (set "choosedList=!_checklist[%%i]!")
	)
)
Endlocal && (set "%~1=%choosedList%")
exit /b

::====================================================================

:EOF
call :WriteToConsoleAndToLog

if !endedWithErrors!==0 (
	call :WriteToConsoleAndToLog Script ended without catched errors
)
if !endedWithErrors!==1 (
	call :WriteToConsoleAndToLog Script ended, but with some errors
)
if !endedWithErrors!==2 (
	call :WriteToConsoleAndToLog Script terminated with a critical error
)
echo.
echo.
echo Press any button to exit...
pause>NUL

EndLocal

title %comspec%
exit

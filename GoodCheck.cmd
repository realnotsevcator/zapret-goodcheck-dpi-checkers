@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem ============================================================================
rem  GoodCheck.cmd - streamlined test runner for Zapret strategies
rem  This version rewrites the previous script with a smaller and more reliable
rem  command flow. Unused features that interfered with execution were removed
rem  while keeping the interactive workflow intact.
rem ============================================================================

chcp 1251 >NUL

set "SCRIPT_NAME=GoodCheck"
set "SCRIPT_VERSION=2.1.0"
set "ROOT_DIR=%~dp0"
if not defined ROOT_DIR set "ROOT_DIR=.\"

rem ----- defaults -------------------------------------------------------------
set "logsFolder=Logs"
set "strategiesFolder=Strategies"
set "curlFolder=Curl"
set "checkListFolder=Checklists"
set "mostSuccessfulStrategiesFile=MostSuccessfulStrategies.txt"
set "outputMostSuccessfulStrategiesSeparately=false"
set "curlExtraKeys="
set "curlMinTimeout=2"
set "tcp1620TimeoutMs=5000"
set "tcp1620OkThresholdBytes=65536"
set "tcp1620CustomId=CUST-01"
set "tcp1620CustomProvider=Custom"
set "tcp1620CustomUrl="
set "tcp1620CustomTimes=1"
set "fakeSNI=www.google.com"
set "fakeHexRaw=1603030135010001310303424143facf5c983ac8ff20b819cfd634cbf5143c0005b2b8b142a6cd335012c220008969b6b387683dedb4114d466ca90be3212b2bde0c4f56261a9801"
set "fakeHexBytes="
set "netConnTestURL=https://ya.ru"
set "zapretName=Zapret"
set "zapretExeName=winws.exe"
set "zapretFolderOverride="
set "zapretServiceName=winws1"

rem ----- runtime --------------------------------------------------------------
set "LOG_FILE="
set "exitCode=0"
set "strategiesList="
set "strategiesCount=-1"
set "curlThreadsNum=0"
set "testCaseCount=-1"
set "numberOfPasses=1"
set "mostSuccessful=-1"

call :ApplyConfigOverrides
call :CreateLog || goto FINISH
call :Log "=============================="
call :Log "%SCRIPT_NAME% %SCRIPT_VERSION%"
call :Log "=============================="

call :RequireAdmin || (set "exitCode=2" & goto FINISH)
call :LocateStrategiesFolder || (set "exitCode=2" & goto FINISH)
call :LocateCurl || (set "exitCode=2" & goto FINISH)
call :CheckNetwork || (set "exitCode=2" & goto FINISH)
call :LocateProgram || (set "exitCode=2" & goto FINISH)
call :ChooseStrategyFile || (set "exitCode=2" & goto FINISH)
call :LoadStrategies || (set "exitCode=2" & goto FINISH)
call :ConfigureTests || (set "exitCode=2" & goto FINISH)
call :AskPassCount || (set "exitCode=2" & goto FINISH)
call :PrepareEnvironment
call :RunTests
call :Summarize

:FINISH
call :Log ""
if %exitCode% GEQ 2 (
    call :Log "Script finished with errors."
) else if %exitCode% EQU 1 (
    call :Log "Script finished with warnings."
) else (
    call :Log "Script completed successfully."
)
if defined LOG_FILE call :Log "Log file: %LOG_FILE%"
call :Log ""
if "%CMDCMDLINE%"=="%""%SystemRoot%\system32\cmd.exe""" call :Log "Press any key to exit..." & pause >NUL
endlocal & exit /b %exitCode%

rem ============================================================================
:ApplyConfigOverrides
setlocal EnableDelayedExpansion
for %%V in (
    logsFolder strategiesFolder curlFolder checkListFolder mostSuccessfulStrategiesFile ^
    outputMostSuccessfulStrategiesSeparately curlExtraKeys curlMinTimeout tcp1620TimeoutMs ^
    tcp1620OkThresholdBytes tcp1620CustomId tcp1620CustomProvider tcp1620CustomUrl ^
    tcp1620CustomTimes fakeSNI fakeHexRaw fakeHexBytes netConnTestURL zapretName ^
    zapretExeName zapretFolderOverride zapretServiceName
) do (
    for /f "delims=" %%O in ("!_%%V!") do if not "%%O"=="" set "%%V=%%O"
)
endlocal & exit /b 0

rem ============================================================================
:CreateLog
setlocal EnableDelayedExpansion
set "logsDir=%ROOT_DIR%%logsFolder%"
if not exist "!logsDir!" (
    mkdir "!logsDir!" 2>NUL
    if errorlevel 1 (
        echo ERROR: cannot create log directory "!logsDir!"
        exit /b 1
    )
)
set "ts=%date%_%time%"
set "ts=!ts::=-!"
set "ts=!ts:/=-!"
set "ts=!ts:.=-!"
set "ts=!ts:,=-!"
set "ts=!ts: =0!"
set "logName=Log_%SCRIPT_NAME%_!ts!.txt"
set "logPath=!logsDir!\!logName!"
>"!logPath!" echo %SCRIPT_NAME% %SCRIPT_VERSION% log
if errorlevel 1 (
    echo ERROR: cannot create log file "!logPath!"
    exit /b 1
)
endlocal & set "LOG_FILE=%logPath%" & exit /b 0

rem ============================================================================
:Log
setlocal DisableDelayedExpansion
set "message=%~1"
if defined LOG_FILE (
    if "%~1"=="" (
        >>"%LOG_FILE%" echo.
    ) else (
        >>"%LOG_FILE%" echo %message%
    )
)
if "%~1"=="" (
    echo.
) else (
    echo %message%
)
endlocal & exit /b 0

rem ============================================================================
:RequireAdmin
fsutil dirty query %systemdrive% >NUL 2>&1
if errorlevel 1 (
    call :Log "ERROR: Administrator privileges are required."
    call :Log "Run %~nx0 as administrator."
    exit /b 1
)
call :Log "Administrator privileges confirmed."
exit /b 0

rem ============================================================================
:LocateStrategiesFolder
set "strategiesDir=%ROOT_DIR%%strategiesFolder%"
if not exist "%strategiesDir%" (
    call :Log "ERROR: strategies folder not found (%strategiesDir%)."
    exit /b 1
)
call :Log "Strategies folder: %strategiesDir%"
exit /b 0

rem ============================================================================
:LocateCurl
set "curl="
set "archDir=x86"
if /I "%PROCESSOR_ARCHITECTURE%"=="AMD64" set "archDir=x86_64"
if defined PROCESSOR_ARCHITEW6432 set "archDir=x86_64"
if exist "%ROOT_DIR%%curlFolder%\%archDir%\curl.exe" set "curl=%ROOT_DIR%%curlFolder%\%archDir%\curl.exe"
if not defined curl if exist "%ROOT_DIR%%curlFolder%\curl.exe" set "curl=%ROOT_DIR%%curlFolder%\curl.exe"
if not defined curl if exist "%ROOT_DIR%curl.exe" set "curl=%ROOT_DIR%curl.exe"
if not defined curl (
    for %%P in ("%SystemRoot%\System32\curl.exe" "%SystemRoot%\SysWOW64\curl.exe") do (
        if not defined curl if exist "%%~fP" set "curl=%%~fP"
    )
)
if not defined curl (
    if exist "%SystemRoot%\System32\where.exe" (
        for /f "delims=" %%P in ('"%SystemRoot%\System32\where.exe" curl.exe 2^>NUL') do (
            if not defined curl set "curl=%%~fP"
        )
    )
)
if not defined curl (
    call :Log "ERROR: curl executable not found."
    exit /b 1
)
for /f "usebackq delims=" %%L in (`"%curl%" -V 2^>NUL`) do (
    if defined LOG_FILE >>"%LOG_FILE%" echo(curl: %%L
    echo(curl: %%L
)
exit /b 0

rem ============================================================================
:CheckNetwork
"%curl%" --silent --show-error --max-time %curlMinTimeout% --output NUL "%netConnTestURL%" >NUL 2>&1
if errorlevel 1 (
    call :Log "WARNING: HTTPS connectivity failed, retrying with --insecure."
    "%curl%" --silent --show-error --max-time %curlMinTimeout% --insecure --output NUL "%netConnTestURL%" >NUL 2>&1
    if errorlevel 1 (
        call :Log "WARNING: network connectivity test failed; continuing without pre-check."
        call :Log "WARNING: HTTP checks may report DETECTED/FAIL until connectivity issues are resolved."
        set "NETWORK_WARNING=1"
        if !exitCode! LSS 1 set "exitCode=1"
        exit /b 0
    )
    set "curlExtraKeys=%curlExtraKeys% --insecure"
)
exit /b 0

rem ============================================================================
:LocateProgram
set "exeFullpath="
if defined zapretFolderOverride (
    for %%P in ("%zapretFolderOverride%\%zapretExeName%" "%zapretFolderOverride%%zapretExeName%") do (
        if exist "%%~fP" set "exeFullpath=%%~fP"
    )
)
if not defined exeFullpath (
    for %%P in ("%ROOT_DIR%%zapretExeName%" "%ROOT_DIR%\%zapretExeName%" "%ROOT_DIR%zapret-winws\%zapretExeName%") do (
        if exist "%%~fP" set "exeFullpath=%%~fP"
    )
)
if not defined exeFullpath (
    call :Log "ERROR: %zapretName% executable not found."
    exit /b 1
)
call :Log "%zapretName% executable: %exeFullpath%"
exit /b 0

rem ============================================================================
:ChooseStrategyFile
setlocal EnableDelayedExpansion
set "strategiesDir=%ROOT_DIR%%strategiesFolder%"
set "index=-1"
for %%F in ("%strategiesDir%\*.txt") do (
    set /a index+=1
    set "item[!index!]=%%~fF"
    call :Log "[!index!] %%~nF"
)
if !index! LSS 0 (
    call :Log "ERROR: no strategy files in %strategiesDir%."
    exit /b 1
)
:ASK_STRATEGY
set /p "selection=Select strategy list (number or X to cancel): "
if /I "!selection!"=="X" exit /b 1
if not defined selection goto ASK_STRATEGY
for /f "delims=0123456789" %%D in ("!selection!") do goto ASK_STRATEGY
if !selection! GTR !index! goto ASK_STRATEGY
set "chosen=!item[!selection!]!"
call :Log "Selected strategy list: !chosen!"
endlocal & set "strategiesList=%chosen%" & exit /b 0

rem ============================================================================
:LoadStrategies
if not defined strategiesList (
    call :Log "ERROR: strategy list not selected."
    exit /b 1
)
set "strategiesCount=-1"
set "strategyExtraKeys="
set "strategyCurlExtraKeys="
for /f "usebackq tokens=*" %%L in ("%strategiesList%") do (
    set "line=%%L"
    if not defined line goto NEXT_STRAT
    if "!line!"=="" goto NEXT_STRAT
    if "!line:~0,1!"=="/" goto NEXT_STRAT
    for /f "tokens=1* delims=#" %%A in ("!line!") do (
        if /I "%%A"=="_strategyExtraKeys" (
            set "strategyExtraKeys=%%B"
            goto NEXT_STRAT
        )
        if /I "%%A"=="_strategyCurlExtraKeys" (
            set "strategyCurlExtraKeys=%%B"
            goto NEXT_STRAT
        )
    )
    set "strategy=!strategyExtraKeys! !line!"
    if defined fakeSNI set "strategy=!strategy:FAKESNI=%fakeSNI%!"
    if defined fakeHexRaw set "strategy=!strategy:FAKEHEX=%fakeHexRaw%!"
    if defined fakeHexBytes set "strategy=!strategy:FAKEHEXBYTES=%fakeHexBytes%!"
    set /a strategiesCount+=1
    set "strategies[!strategiesCount!]=!strategy!"
:NEXT_STRAT
)
if %strategiesCount% LSS 0 (
    call :Log "ERROR: selected strategy list is empty."
    exit /b 1
)
if defined strategyCurlExtraKeys set "curlExtraKeys=%curlExtraKeys% !strategyCurlExtraKeys!"
set /a totalStrategies=%strategiesCount%+1
call :Log "Loaded %totalStrategies% strategies."
exit /b 0

rem ============================================================================
:ConfigureTests
set /a testCaseCount=-1
set /a curlThreadsNum=0
for %%T in (
    "CF-01|Cloudflare|https://speed.cloudflare.com/__down?bytes=65536|1"
    "CF-02|Cloudflare|https://www.cloudflare.com/cdn-cgi/trace|1"
    "HZ-01|Hetzner|https://mirror.hetzner.com/100MB.bin|1"
    "OVH-01|OVH|https://proof.ovh.net/files/1Mb.dat|1"
    "OVH-02|OVH|https://ovh.sfx.ovh/10M.bin|1"
    "OR-01|Oracle|https://oracle.sfx.ovh/10M.bin|1"
    "AWS-01|AWS|https://tms.delta.com/delta/dl_anderson/Bootstrap.js|1"
    "AWS-02|AWS|https://corp.kaltura.com/wp-content/cache/min/1/wp-content/themes/airfleet/dist/styles/theme.css|1"
    "FST-01|Fastly|https://www.juniper.net/content/dam/www/assets/images/diy/DIY_th.jpg/jcr:content/renditions/600x600.jpeg|1"
    "FST-02|Fastly|https://www.graco.com/etc.clientlibs/clientlib-site/resources/fonts/lato/Lato-Regular.woff2|1"
    "AKM-01|Akamai|https://www.lg.com/lg5-common-gp/library/jquery.min.js|1"
    "AKM-02|Akamai|https://media-assets.stryker.com/is/image/stryker/gateway_1?$max_width_1410$|1"
) do (
    set "entry=%%~T"
    set /a testCaseCount+=1
    for /f "tokens=1-4 delims=|" %%A in ("!entry!") do (
        set "testId[!testCaseCount!]=%%~A"
        set "testProvider[!testCaseCount!]=%%~B"
        set "testUrl[!testCaseCount!]=%%~C"
        set "testTimes[!testCaseCount!]=%%~D"
        if "!testTimes[!testCaseCount!]!"=="" set "testTimes[!testCaseCount!]=1"
        set /a curlThreadsNum+=!testTimes[!testCaseCount!]!
    )
)
if defined tcp1620CustomUrl if not "%tcp1620CustomUrl%"=="" (
    set "customTimes=%tcp1620CustomTimes%"
    if not defined customTimes set "customTimes=1"
    set /a testCaseCount+=1
    set "testId[!testCaseCount!]=%tcp1620CustomId%"
    set "testProvider[!testCaseCount!]=%tcp1620CustomProvider%"
    set "testUrl[!testCaseCount!]=%tcp1620CustomUrl%"
    set "testTimes[!testCaseCount!]=!customTimes!"
    set /a curlThreadsNum+=customTimes
)
if %curlThreadsNum% LEQ 0 (
    call :Log "ERROR: no HTTP tests configured."
    exit /b 1
)
set /a testCaseTotal=%testCaseCount%+1
call :Log "Configured %curlThreadsNum% HTTP checks across %testCaseTotal% test cases."
exit /b 0

rem ============================================================================
:AskPassCount
set "numberOfPasses=1"
:ASK_PASS
set /p "numberOfPasses=Number of passes (1-9, default 1): "
if not defined numberOfPasses set "numberOfPasses=1"
for /f "delims=0123456789" %%D in ("%numberOfPasses%") do goto ASK_PASS
if %numberOfPasses% LEQ 0 goto ASK_PASS
if %numberOfPasses% GTR 9 goto ASK_PASS
call :Log "Passes selected: %numberOfPasses%"
exit /b 0

rem ============================================================================
:PrepareEnvironment
call :Log "Preparing environment..."
call :TerminateProgram "%zapretExeName%"
call :TerminateService "%zapretServiceName%"
call :TerminateHelpers
exit /b 0

rem ============================================================================
:RunTests
set /a tcp1620TimeoutSec=(tcp1620TimeoutMs+999)/1000
if %tcp1620TimeoutSec% LSS 1 set "tcp1620TimeoutSec=1"
set /a maxStrategy=%strategiesCount%
for /L %%S in (0,1,%maxStrategy%) do (
    call :Log ""
    call :Log "Strategy %%S of %maxStrategy%: !strategies[%%S]!"
    start "" /min "%exeFullpath%" !strategies[%%S]!
    timeout /T 1 >NUL
    set "bestScore=-1"
    set "bestSummary=No data"
    for /L %%P in (1,1,%numberOfPasses%) do (
        call :RunTestSuite passScore summaryText
        call :Log "Pass %%P: !passScore!/!curlThreadsNum! (!summaryText!)"
        if !bestScore! LSS 0 (
            set "bestScore=!passScore!"
            set "bestSummary=!summaryText!"
        ) else if !passScore! LSS !bestScore! (
            set "bestScore=!passScore!"
            set "bestSummary=!summaryText!"
        )
    )
    call :TerminateProgram "%zapretExeName%"
    set "results[%%S]=!bestScore!|!strategies[%%S]!|!bestSummary!"
    if !bestScore! GTR !mostSuccessful! set "mostSuccessful=!bestScore!"
)
exit /b 0

rem ============================================================================
:RunTestSuite
setlocal EnableDelayedExpansion
set /a ok=0, warn=0, detected=0, fail=0
for /L %%T in (0,1,%testCaseCount%) do (
    set "currentId=!testId[%%T]!"
    set "currentProvider=!testProvider[%%T]!"
    set "currentUrl=!testUrl[%%T]!"
    set "repeat=!testTimes[%%T]!"
    if not defined repeat set "repeat=1"
    for /L %%R in (1,1,!repeat!) do (
        call :RunSingleTest "!currentId!" "!currentProvider!" "!currentUrl!" %%R !repeat! status statusText bytes http ip err
        if /I "!status!"=="OK" (
            set /a ok+=1
        ) else if /I "!status!"=="WARN" (
            set /a warn+=1
        ) else if /I "!status!"=="DETECTED" (
            set /a detected+=1
        ) else (
            set /a fail+=1
        )
        call :Log "Test !currentId! (#%%R/!repeat!) - !statusText! (HTTP !http!, bytes !bytes!, IP !ip!, error !err!)"
    )
)
set "summary=OK:!ok!, Warn:!warn!, Detected:!detected!, Fail:!fail!"
set /a okCount=ok
endlocal & (set "%~1=%okCount%" & set "%~2=%summary%") & exit /b 0

rem ============================================================================
:RunSingleTest
setlocal EnableDelayedExpansion
set "testId=%~1"
set "testProvider=%~2"
set "testUrl=%~3"
set "iteration=%~4"
set "iterationTotal=%~5"
set "curlMeta="
set "curlError="
call :AppendQuery "%testUrl%" requestUrl
set "writeOut=HTTP_CODE=%%{http_code};SIZE=%%{size_download};IP=%%{remote_ip};ERR=%%{errormsg}"
for /f "usebackq delims=" %%L in (`"%curl%" %curlExtraKeys% --silent --show-error --no-progress-meter --max-time %tcp1620TimeoutSec% --connect-timeout %tcp1620TimeoutSec% --range 0-65535 --output NUL --write-out "%writeOut%" "!requestUrl!" 2^>^&1`) do (
    set "line=%%L"
    if not defined curlMeta (
        if not "!line:HTTP_CODE=!=!line!"=="" (
            set "curlMeta=!line!"
        ) else if not defined curlError set "curlError=!line!"
    ) else (
        if not "!line:HTTP_CODE=!=!line!"=="" set "curlMeta=!line!"
    )
)
set "curlExit=!ERRORLEVEL!"
set "httpCode=000"
set "downloadSize=0"
set "remoteIp=unknown"
set "errorMessage="
if defined curlMeta (
    for /f "tokens=1-4 delims=;" %%A in ("!curlMeta!") do (
        for /f "tokens=2 delims==" %%p in ("%%A") do set "httpCode=%%p"
        for /f "tokens=2 delims==" %%p in ("%%B") do set "downloadSize=%%p"
        for /f "tokens=2 delims==" %%p in ("%%C") do set "remoteIp=%%p"
        for /f "tokens=2 delims==" %%p in ("%%D") do set "errorMessage=%%p"
    )
)
if not defined errorMessage if defined curlError set "errorMessage=!curlError!"
for /f "tokens=1 delims=." %%B in ("!downloadSize!") do set "downloadSize=%%B"
if not defined downloadSize set "downloadSize=0"
set "status=FAIL"
set "statusText=Failed to complete"
if "!curlExit!"=="0" (
    if !downloadSize! GEQ %tcp1620OkThresholdBytes% (
        set "status=OK"
        set "statusText=Not detected"
    ) else (
        set "status=WARN"
        set "statusText=Possibly detected"
    )
) else if "!curlExit!"=="28" (
    set "status=DETECTED"
    if "!httpCode!"=="000" (
        set "statusText=Detected (timeout without HTTP)"
    ) else (
        set "statusText=Detected"
    )
) else (
    if not defined errorMessage set "errorMessage=exit !curlExit!"
)
if not defined errorMessage set "errorMessage=none"
endlocal & (
    set "%~6=%status%"
    set "%~7=%statusText%"
    set "%~8=%downloadSize%"
    set "%~9=%httpCode%"
    set "%~10=%remoteIp%"
    set "%~11=%errorMessage%"
) & exit /b 0

rem ============================================================================
:AppendQuery
setlocal EnableDelayedExpansion
set "base=%~1"
set "marker=?"
if not "!base:?=!"=="!base!" set "marker=&"
set "rand=%random%%random%%random%"
set "result=!base!!marker!t=!rand!"
endlocal & set "%~2=%result%" & exit /b 0

rem ============================================================================
:Summarize
setlocal EnableDelayedExpansion
call :Log ""
call :Log "Summary by success count:"
for /L %%S in (0,1,%curlThreadsNum%) do (
    set "line="
    for /L %%I in (0,1,%strategiesCount%) do (
        for /f "tokens=1-3 delims=|" %%A in ("!results[%%I]!") do (
            if %%A==%%S (
                if not defined line set "line=Strategies:"
                set "line=!line! %%B (%%C)"
            )
        )
    )
    if defined line call :Log "%%S successes - !line!"
)
if /I "%outputMostSuccessfulStrategiesSeparately%"=="true" call :WriteMostSuccessful
endlocal & exit /b 0

rem ============================================================================
:WriteMostSuccessful
setlocal EnableDelayedExpansion
if %mostSuccessful% LSS 0 exit /b 0
set "targetFile=%mostSuccessfulStrategiesFile%"
if "!targetFile!"=="" set "targetFile=MostSuccessfulStrategies.txt"
for %%F in ("!targetFile!") do (
    set "base=%%~dpnF"
    set "ext=%%~xF"
)
if "!base!"=="" set "base=!targetFile!"
if "!ext!"=="" set "ext=.txt"
set "targetFile=!base!_%zapretName!!ext!"
if exist "!targetFile!" del "!targetFile!"
for /L %%I in (0,1,%strategiesCount%) do (
    for /f "tokens=1-3 delims=|" %%A in ("!results[%%I]!") do (
        if %%A==%mostSuccessful% echo %%B>>"!targetFile!"
    )
)
if exist "!targetFile!" call :Log "Best strategies exported to !targetFile!."
endlocal & exit /b 0

rem ============================================================================
:TerminateProgram
set "proc=%~1"
if not defined proc exit /b 0
for %%P in (%proc%) do taskkill /F /IM %%~P >NUL 2>&1
exit /b 0

rem ============================================================================
:TerminateService
set "service=%~1"
if not defined service exit /b 0
sc query "%service%" >NUL 2>&1
if errorlevel 1 exit /b 0
sc stop "%service%" >NUL 2>&1
sc delete "%service%" >NUL 2>&1
exit /b 0

rem ============================================================================
:TerminateHelpers
taskkill /F /IM wintun.exe >NUL 2>&1
for %%W in (winwfphelper.exe windivert.exe winws.exe) do taskkill /F /IM %%W >NUL 2>&1
exit /b 0

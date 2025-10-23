@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem ============================================================================
rem  GoodCheck - simplified and cleaned-up test runner for Zapret strategies
rem  Completely rewritten version focused on reliability and clear structure.
rem ============================================================================

chcp 1251 >NUL

set "SCRIPT_NAME=GoodCheck"
set "SCRIPT_VERSION=2.0.0"
set "ROOT_DIR=%~dp0"
if not defined ROOT_DIR set "ROOT_DIR=.\"

rem ----- default configuration -------------------------------------------------
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
set "mostSuccessfulStrategiesFile=MostSuccessfulStrategies.txt"
set "strategiesFolder=Strategies"
set "logsFolder=Logs"
set "curlFolder=Curl"
set "checkListFolder=Checklists"
set "netConnTestURL=https://ya.ru"
set "zapretName=Zapret"
set "zapretExeName=winws.exe"
set "zapretFolderOverride="
set "zapretServiceName=winws1"

rem ----- runtime variables -----------------------------------------------------
set "exitCode=0"
set "LOG_FILE="
set "strategiesList="
set "strategyExtraKeys="
set "strategyCurlExtraKeys="
set "curl="
set "curlThreadsNum=0"
set "testCaseCount=-1"
set "mostSuccessful=-1"

rem Apply any overrides that were supplied through Config.cmd-style variables
for %%V in (
    outputMostSuccessfulStrategiesSeparately curlExtraKeys curlMinTimeout tcp1620TimeoutMs tcp1620OkThresholdBytes ^
    tcp1620CustomId tcp1620CustomProvider tcp1620CustomUrl tcp1620CustomTimes fakeSNI fakeHexRaw fakeHexBytes ^
    mostSuccessfulStrategiesFile strategiesFolder logsFolder curlFolder ^
    checkListFolder netConnTestURL zapretName zapretExeName zapretFolderOverride zapretServiceName
) do (
    for /f "delims=" %%O in ("!_%%V!") do if not "%%O"=="" set "%%V=%%O"
)
call :CreateLog || goto FINISH
call :Log "---------------------"
call :Log "%SCRIPT_NAME% %SCRIPT_VERSION% starting up"
call :Log "---------------------"

call :RequireAdmin || (set "exitCode=2" & goto FINISH)
set "strategiesDir=%ROOT_DIR%%strategiesFolder%"
if not exist "%strategiesDir%" (
    call :Log "ERROR: strategies folder not found at %strategiesDir%"
    set "exitCode=2"
    goto FINISH
)
call :LocateCurl || (set "exitCode=2" & goto FINISH)
call :VerifyCurlConnectivity || (set "exitCode=2" & goto FINISH)
call :LocatePrograms
if not defined exeFullpath (
    call :Log "ERROR: %zapretName% executable not found. Configure path via Config.cmd."
    set "exitCode=2"
    goto FINISH
)

call :PickStrategyList || (set "exitCode=2" & goto FINISH)
call :LoadStrategies || (set "exitCode=2" & goto FINISH)
call :BuildTestMatrix || (set "exitCode=2" & goto FINISH)
call :ChoosePassCount || (set "exitCode=2" & goto FINISH)
call :PrepareEnvironment
call :RunTestMatrix
call :SummarizeResults

goto FINISH

rem ============================================================================
:FINISH
call :Log ""
if %exitCode% GEQ 2 (
    call :Log "Script finished with errors."
) else if %exitCode% EQU 1 (
    call :Log "Script finished with warnings."
) else (
    call :Log "Script completed successfully."
)
call :Log "Log file: %LOG_FILE%"
call :Log ""
call :Log "Press any key to exit..."
pause >NUL
endlocal
exit /b %exitCode%

rem ============================================================================
:CreateLog
setlocal EnableDelayedExpansion
set "logsDir=%ROOT_DIR%%logsFolder%"
if not exist "%logsDir%" (
    mkdir "%logsDir%" 2>NUL
    if errorlevel 1 (
        echo ERROR: cannot create log directory "%logsDir%"
        exit /b 1
    )
)
for /f "tokens=1-3 delims=.:/ " %%a in ("%date% %time%") do set "ts=%%a-%%b-%%c"
set "ts=%ts::=-%"
set "ts=%ts: =0%"
set "logName=Log_%SCRIPT_NAME%_%ts%.txt"
set "logPath=%logsDir%\%logName%"
>"%logPath%" echo %SCRIPT_NAME% %SCRIPT_VERSION% log
if errorlevel 1 (
    echo ERROR: cannot create log file "%logPath%"
    exit /b 1
)
endlocal & set "LOG_FILE=%logPath%" & exit /b 0

rem ============================================================================
:Log
setlocal DisableDelayedExpansion
set "message=%~1"
if defined LOG_FILE (
    >>"%LOG_FILE%" echo %message%
)
echo %message%
endlocal & exit /b 0

rem ============================================================================
:RequireAdmin
fsutil dirty query %systemdrive% >NUL 2>&1
if errorlevel 1 (
    call :Log "ERROR: Administrator privileges are required."
    call :Log "Right click on %~nx0 and choose 'Run as administrator'."
    exit /b 1
)
call :Log "Administrator privileges confirmed."
exit /b 0

:LocateCurl
set "curl="
set "archDir=x86"
if /I "%PROCESSOR_ARCHITECTURE%"=="AMD64" set "archDir=x86_64"
if defined PROCESSOR_ARCHITEW6432 set "archDir=x86_64"
if defined curlFolder (
    for %%P in ("%ROOT_DIR%%curlFolder%\%archDir%\curl.exe" "%ROOT_DIR%%curlFolder%\curl.exe") do (
        if not defined curl if exist "%%~fP" set "curl=%%~fP"
    )
)
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
for /f "usebackq tokens=*" %%V in (`"%curl%" -V 2^>NUL`) do (
    call :Log "curl: %%V"
)
exit /b 0

rem ============================================================================
:VerifyCurlConnectivity
set /a "timeoutSec=(tcp1620TimeoutMs+999)/1000"
if %timeoutSec% LSS 1 set "timeoutSec=1"
"%curl%" --silent --show-error --max-time %curlMinTimeout% --output NUL "%netConnTestURL%" >NUL 2>&1
if errorlevel 1 (
    call :Log "WARNING: secure connectivity failed, retrying without certificate validation."
    "%curl%" --silent --show-error --max-time %curlMinTimeout% --insecure --output NUL "%netConnTestURL%" >NUL 2>&1
    if errorlevel 1 (
        call :Log "ERROR: network connectivity test failed."
        exit /b 1
    )
    set "curlExtraKeys=%curlExtraKeys% --insecure"
)
exit /b 0

rem ============================================================================
:LocatePrograms
set "exeFullpath="
if defined zapretFolderOverride (
    for %%P in ("%zapretFolderOverride%%zapretExeName%" "%zapretFolderOverride%\%zapretExeName%") do (
        if exist "%%~fP" set "exeFullpath=%%~fP"
    )
)
if not defined exeFullpath (
    for %%P in ("%ROOT_DIR%\%zapretExeName%" "%ROOT_DIR%zapret-winws\%zapretExeName%" "%ROOT_DIR%%zapretExeName%") do (
        if exist "%%~fP" set "exeFullpath=%%~fP"
    )
)
if defined exeFullpath (
    call :Log "%zapretName% found at %exeFullpath%"
)
exit /b 0

rem ============================================================================
:PickStrategyList
setlocal EnableDelayedExpansion
set "strategiesDir=%ROOT_DIR%%strategiesFolder%"
set "index=-1"
for %%F in ("%strategiesDir%\*.txt") do (
    set /a index+=1
    set "item[!index!]=%%~fF"
    call :Log "[!index!] %%~nF"
)
if %index% LSS 0 (
    call :Log "ERROR: no strategy lists found in %strategiesDir%."
    exit /b 1
)
:SELECT_STRATEGY
set /p "selection=Enter strategy number (or X to cancel): "
if /I "!selection!"=="X" exit /b 1
for /f "delims=0123456789" %%X in ("!selection!") do if not "%%X"=="" goto SELECT_STRATEGY
if not defined selection goto SELECT_STRATEGY
if %selection% GTR %index% goto SELECT_STRATEGY
set "chosen=!item[%selection%]!"
call :Log "Selected strategy list: !chosen!"
endlocal & set "strategiesList=%chosen%" & exit /b 0

rem ============================================================================
:LoadStrategies
if not defined strategiesList (
    call :Log "ERROR: strategy list not selected."
    exit /b 1
)
set "strategyExtraKeys="
set "strategyCurlExtraKeys="
set "strategiesCount=-1"
for /f "usebackq tokens=* delims=" %%L in ("%strategiesList%") do (
    set "line=%%L"
    if not defined line goto CONTINUE_STRAT
    if "!line!"=="" goto CONTINUE_STRAT
    if "!line:~0,1!"=="/" goto CONTINUE_STRAT
    for /f "tokens=1* delims=#" %%A in ("!line!") do (
        if /I "%%A"=="_strategyExtraKeys" (
            set "strategyExtraKeys=%%B"
            goto CONTINUE_STRAT
        )
        if /I "%%A"=="_strategyCurlExtraKeys" (
            set "strategyCurlExtraKeys=%%B"
            goto CONTINUE_STRAT
        )
    )
    set "strategy=!strategyExtraKeys! !line!"
    if defined fakeSNI set "strategy=!strategy:FAKESNI=%fakeSNI%!"
    if defined fakeHexRaw set "strategy=!strategy:FAKEHEX=%fakeHexRaw%!"
    if defined fakeHexBytes set "strategy=!strategy:FAKEHEXBYTES=%fakeHexBytes%!"
    set /a strategiesCount+=1
    set "strategies[!strategiesCount!]=!strategy!"
:CONTINUE_STRAT
)
if %strategiesCount% LSS 0 (
    call :Log "ERROR: no strategies defined in list."
    exit /b 1
)
if defined strategyCurlExtraKeys set "curlExtraKeys=%curlExtraKeys% !strategyCurlExtraKeys!"
set /a strategiesTotal=%strategiesCount%+1
call :Log "Loaded %strategiesTotal% strategies."
exit /b 0

rem ============================================================================
:BuildTestMatrix
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
if defined tcp1620CustomUrl (
    if not "!tcp1620CustomUrl!"=="" (
        set "customTimes=%tcp1620CustomTimes%"
        if not defined customTimes set "customTimes=1"
        set /a testCaseCount+=1
        set "testId[!testCaseCount!]=%tcp1620CustomId%"
        set "testProvider[!testCaseCount!]=%tcp1620CustomProvider%"
        set "testUrl[!testCaseCount!]=%tcp1620CustomUrl%"
        set "testTimes[!testCaseCount!]=!customTimes!"
        set /a curlThreadsNum+=customTimes
    )
)
if %curlThreadsNum% LEQ 0 (
    call :Log "ERROR: no tests configured."
    exit /b 1
)
set /a testCaseTotal=%testCaseCount%+1
call :Log "Configured %curlThreadsNum% HTTP checks across %testCaseTotal% test cases."
exit /b 0

rem ============================================================================
:ChoosePassCount
set "numberOfPasses=1"
:ASK_PASS
set /p "numberOfPasses=Enter number of passes (1-9, default 1): "
if not defined numberOfPasses set "numberOfPasses=1"
for /f "delims=0123456789" %%X in ("%numberOfPasses%") do goto ASK_PASS
if %numberOfPasses% LEQ 0 goto ASK_PASS
if %numberOfPasses% GTR 9 goto ASK_PASS
call :Log "Number of passes: %numberOfPasses%"
exit /b 0

rem ============================================================================
:PrepareEnvironment
call :Log "Stopping related services and processes..."
call :TerminateProgram "%zapretExeName%"
call :TerminateService "%zapretServiceName%"
call :TerminateWinDivert
exit /b 0

rem ============================================================================
:RunTestMatrix
set /a "tcp1620TimeoutSec=(tcp1620TimeoutMs+999)/1000"
if %tcp1620TimeoutSec% LSS 1 set "tcp1620TimeoutSec=1"
set /a "strategyIndexMax=%strategiesCount%"
for /L %%S in (0,1,%strategyIndexMax%) do (
    call :Log "Running strategy %%S of %strategyIndexMax%: !strategies[%%S]!"
    start "" /min "%exeFullpath%" !strategies[%%S]!
    timeout /T 1 >NUL
    set "bestPass=0"
    set "bestSummary=No data"
    for /L %%P in (1,1,%numberOfPasses%) do (
        call :RunTcp1620Suite suiteResult summaryText
        set "passSuccess=!suiteResult!"
        if %%P EQU 1 (
            set "bestPass=!passSuccess!"
            set "bestSummary=!summaryText!"
        ) else (
            if !passSuccess! LSS !bestPass! (
                set "bestPass=!passSuccess!"
                set "bestSummary=!summaryText!"
            )
        )
        call :Log "Pass %%P result: !passSuccess!/!curlThreadsNum! (!summaryText!)"
    )
    call :TerminateProgram "%zapretExeName%"
    set "resultsArray[%%S]=!bestPass!|!strategies[%%S]!|!bestSummary!"
    if !bestPass! GTR !mostSuccessful! set "mostSuccessful=!bestPass!"
)
exit /b 0

rem ============================================================================
:RunTcp1620Suite
setlocal EnableDelayedExpansion
set /a ok=0, warn=0, detected=0, fail=0, total=0
for /L %%T in (0,1,%testCaseCount%) do (
    set "currentId=!testId[%%T]!"
    set "currentProvider=!testProvider[%%T]!"
    set "currentUrl=!testUrl[%%T]!"
    set "repeat=!testTimes[%%T]!"
    if not defined repeat set "repeat=1"
    for /L %%R in (1,1,!repeat!) do (
        set /a total+=1
        call :RunSingleTcp1620Test "!currentId!" "!currentProvider!" "!currentUrl!" %%R !repeat! statusShort statusText bytes httpCode remoteIp errorMsg
        if /I "!statusShort!"=="OK" (
            set /a ok+=1
        ) else if /I "!statusShort!"=="WARN" (
            set /a warn+=1
        ) else if /I "!statusShort!"=="DETECTED" (
            set /a detected+=1
        ) else (
            set /a fail+=1
        )
        call :Log "Test !currentId! (#%%R/!repeat!) - !statusText! (HTTP !httpCode!, bytes !bytes!, IP !remoteIp!, error !errorMsg!)"
    )
)
set "summary=OK:!ok!, Warn:!warn!, Detected:!detected!, Fail:!fail!"
endlocal & (
    set "%~1=%ok%"
    set "%~2=%summary%"
) & exit /b 0

rem ============================================================================
:RunSingleTcp1620Test
setlocal EnableDelayedExpansion
set "testId=%~1"
set "testProvider=%~2"
set "testUrl=%~3"
set "iteration=%~4"
set "iterationTotal=%~5"
set "curlMeta="
set "curlErrorLine="
call :AppendUniqueQuery "%testUrl%" uniqueUrl
set "writeOut=HTTP_CODE=%%{http_code};SIZE=%%{size_download};IP=%%{remote_ip};ERR=%%{errormsg}"
for /f "usebackq delims=" %%O in (`"%curl%" %curlExtraKeys% --silent --show-error --no-progress-meter --max-time %tcp1620TimeoutSec% --connect-timeout %tcp1620TimeoutSec% --range 0-65535 --output NUL --write-out "%writeOut%" "!uniqueUrl!" 2^>^&1`) do (
    set "line=%%O"
    if not defined curlMeta (
        if not "!line:HTTP_CODE=!=!line!"=="" (
            set "curlMeta=!line!"
        ) else if not defined curlErrorLine (
            set "curlErrorLine=!line!"
        )
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
if not defined errorMessage if defined curlErrorLine set "errorMessage=!curlErrorLine!"
for /f "tokens=1 delims=." %%p in ("!downloadSize!") do set "downloadSize=%%p"
if not defined downloadSize set "downloadSize=0"
set "statusShort=FAIL"
set "statusText=Failed to complete ⚠️"
if "!curlExit!"=="0" (
    if !downloadSize! GEQ %tcp1620OkThresholdBytes% (
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
    if not defined errorMessage set "errorMessage=exit !curlExit!"
)
if not defined errorMessage set "errorMessage=none"
endlocal & (
    set "%~6=%statusShort%"
    set "%~7=%statusText%"
    set "%~8=%downloadSize%"
    set "%~9=%httpCode%"
    set "%~10=%remoteIp%"
    set "%~11=%errorMessage%"
) & exit /b 0

rem ============================================================================
:AppendUniqueQuery
setlocal EnableDelayedExpansion
set "base=%~1"
set "marker=?"
if not "!base:?=!"=="!base!" set "marker=&"
set "rand=%random%%random%%random%"
set "withQuery=!base!!marker!t=!rand!"
endlocal & set "%~2=%withQuery%" & exit /b 0

rem ============================================================================
:SummarizeResults
setlocal EnableDelayedExpansion
call :Log ""
call :Log "Summary by success count:"
for /L %%S in (0,1,%curlThreadsNum%) do (
    set "line="
    for /L %%I in (0,1,%strategiesCount%) do (
        for /f "tokens=1-3 delims=|" %%A in ("!resultsArray[%%I]!") do (
            if %%A==%%S (
                if not defined line set "line=Strategies:"
                set "line=!line! %%B (%%C)"
            )
        )
    )
    if defined line call :Log "%%S successes - !line!"
)
if /I "%outputMostSuccessfulStrategiesSeparately%"=="true" (
    call :WriteMostSuccessful
)
endlocal & exit /b 0

rem ============================================================================
:WriteMostSuccessful
setlocal EnableDelayedExpansion
if %mostSuccessful% LSS 0 exit /b 0
set "targetFile=%mostSuccessfulStrategiesFile%"
if "!targetFile!"=="" set "targetFile=MostSuccessfulStrategies.txt"
for %%A in ("!targetFile!") do (
    set "base=%%~dpnA"
    set "ext=%%~xA"
)
if "!base!"=="" set "base=!targetFile!"
if "!ext!"=="" set "ext=.txt"
set "targetFile=!base!_%zapretName!!ext!"
if exist "!targetFile!" del "!targetFile!"
for /L %%I in (0,1,%strategiesCount%) do (
    for /f "tokens=1-3 delims=|" %%A in ("!resultsArray[%%I]!") do (
        if %%A==%mostSuccessful% (
            echo %%B>>"!targetFile!"
        )
    )
)
if exist "!targetFile!" (
    call :Log "Best strategies exported to !targetFile!."
)
endlocal & exit /b 0

rem ============================================================================
:TerminateProgram
set "target=%~1"
if not defined target exit /b 0
for %%P in (%target%) do (
    taskkill /F /IM %%~P >NUL 2>&1
)
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
:TerminateWinDivert
taskkill /F /IM wintun.exe >NUL 2>&1
for %%W in (winwfphelper.exe windivert.exe winws.exe) do taskkill /F /IM %%W >NUL 2>&1
exit /b 0

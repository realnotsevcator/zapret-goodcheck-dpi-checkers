chcp 1251

::============================================CONFIG============================================

::Program folder can be set up here; leave empty to search in current folder
set "_zapretFolderOverride="



::Fakes and payloads; leave empty to default
set "_fakeSNI=www.google.com"
set "_fakeHexRaw=1603030135010001310303424143facf5c983ac8ff20b819cfd634cbf5143c0005b2b8b142a6cd335012c220008969b6b387683dedb4114d466ca90be3212b2bde0c4f56261a9801"
set "_fakeHexBytes="
set "_payloadTLS=tls_earth_google_com.bin"
set "_payloadQuic=quic_ietf_www_google_com.bin"



::Curl minimum timeout override, in seconds; decreasing it is hightly unrecommended; leave empty to default (2)
set "_curlMinTimeout="
::Extra keys for curl; leave empty to default
set "_curlExtraKeys="
::TCP 16-20 detection timeout override in milliseconds; leave empty to default (5000)
set "_tcp1620TimeoutMs="
::TCP 16-20 OK threshold override in bytes; leave empty to default (65536)
set "_tcp1620OkThresholdBytes="
::Custom TCP 16-20 test case (leave blank to skip)
set "_tcp1620CustomId="
set "_tcp1620CustomProvider="
set "_tcp1620CustomUrl="
set "_tcp1620CustomTimes="

::Output most successful strategies in a different file; leave empty to default (false)
set "_outputMostSuccessfulStrategiesSeparately="
::Most successful strategies filename; leave empty to default (MostSuccessfulStrategies_ProgramName.txt)
set "_mostSuccessfulStrategiesFile="

::==============================================================================================

cd /d "%~dp0"
"GoodCheck.cmd"

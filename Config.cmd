chcp 1251

::============================================CONFIG============================================

::Program folders can be set up here; leave empty to search in current folder
set "_gdpiFolderOverride="
set "_zapretFolderOverride="
set "_ciaFolderOverride="



::Fakes and payloads; leave empty to default
set "_fakeSNI=www.google.com"
set "_fakeHexRaw=1603030135010001310303424143facf5c983ac8ff20b819cfd634cbf5143c0005b2b8b142a6cd335012c220008969b6b387683dedb4114d466ca90be3212b2bde0c4f56261a9801"
set "_fakeHexBytes="
set "_payloadTLS=tls_earth_google_com.bin"
set "_payloadQuic=quic_ietf_www_google_com.bin"



::Whether to skip an automatic test of your internet provider's Google Cache Server; leave empty to default (false)
set "_skipAutoISPsGCS="
::Whether to skip an automatic test of TLS1.2 breakage; leave empty to default (true)
set "_skipAutoTLS12BreakageTest="

::Curl minimum timeout override, in seconds; decreasing it is hightly unrecommended; leave empty to default (2)
set "_curlMinTimeout="
::Extra keys for curl; leave empty to default
set "_curlExtraKeys="
::Curl anti-hanging mechanic, which start it in another window; leave empty to default (true)
set "_curlAntiFreeze="

::DNS-over-HTTPS resolver state; leave empty to default (true)
set "_dohEnabled="
::DNS-over-HTTPS resolver; leave empty to default (a list of pre-defined resolvers)
set "_curlDoH="
::Common resolver state; leave empty to default (false)
set "_customCommonResolverEnabled="
::Common resolver; leave empty to default (a list of pre-defined resolvers)
set "_resolver="
::Common resolver IP lookup version, either 4 or 6; leave empty to default (4)
set "_customResolverIPv="

::Output most successful strategies in a different file; leave empty to default (false)
set "_outputMostSuccessfulStrategiesSeparately="
::Most successful strategies filename; leave empty to default (MostSuccessfulStrategies_ProgramName.txt)
set "_mostSuccessfulStrategiesFile="

::==============================================================================================

cd /d "%~dp0"
"GoodCheck.cmd"
@echo off
REM Add Octostar and shxo.click host entries to Windows hosts file
REM Run as Administrator!

set HOSTS_FILE=%SystemRoot%\System32\drivers\etc\hosts

REM Backup current hosts file
copy %HOSTS_FILE% %HOSTS_FILE%.bak

REM Octostar and shxo.click entries
setlocal enabledelayedexpansion
set ENTRIES="10.14.100.1 octostar.darkwinds.internal"
set ENTRIES=!ENTRIES! & echo 10.14.100.1 home.octostar.darkwinds.internal
set ENTRIES=!ENTRIES! & echo 10.14.100.1 fusion.octostar.darkwinds.internal
set ENTRIES=!ENTRIES! & echo 10.14.100.1 minio.octostar.darkwinds.internal
set ENTRIES=!ENTRIES! & echo 10.14.100.1 minio-api.octostar.darkwinds.internal
set ENTRIES=!ENTRIES! & echo 10.14.100.1 wss.octostar.darkwinds.internal
set ENTRIES=!ENTRIES! & echo 10.14.100.1 nifi.octostar.darkwinds.internal
set ENTRIES=!ENTRIES! & echo 10.14.100.1 kibana.octostar.darkwinds.internal
set ENTRIES=!ENTRIES! & echo 10.14.100.1 api.octostar.darkwinds.internal
set ENTRIES=!ENTRIES! & echo 10.14.100.1 grafana.octostar.darkwinds.internal
set ENTRIES=!ENTRIES! & echo 10.14.100.1 prometheus.octostar.darkwinds.internal
set ENTRIES=!ENTRIES! & echo 10.14.100.1 shxo.click
set ENTRIES=!ENTRIES! & echo 10.14.100.1 home.shxo.click
set ENTRIES=!ENTRIES! & echo 10.14.100.1 fusion.shxo.click
set ENTRIES=!ENTRIES! & echo 10.14.100.1 minio.shxo.click
set ENTRIES=!ENTRIES! & echo 10.14.100.1 minio-api.shxo.click
set ENTRIES=!ENTRIES! & echo 10.14.100.1 wss.shxo.click
set ENTRIES=!ENTRIES! & echo 10.14.100.1 nifi.shxo.click
set ENTRIES=!ENTRIES! & echo 10.14.100.1 kibana.shxo.click
set ENTRIES=!ENTRIES! & echo 10.14.100.1 api.shxo.click
set ENTRIES=!ENTRIES! & echo 10.14.100.1 grafana.shxo.click
set ENTRIES=!ENTRIES! & echo 10.14.100.1 prometheus.shxo.click

REM Remove any existing entries for these hosts
(for /f "tokens=1,* delims= " %%A in ('type %HOSTS_FILE%') do @echo %%A %%B | findstr /V /I "octostar.darkwinds.internal home.octostar.darkwinds.internal fusion.octostar.darkwinds.internal minio.octostar.darkwinds.internal minio-api.octostar.darkwinds.internal wss.octostar.darkwinds.internal nifi.octostar.darkwinds.internal kibana.octostar.darkwinds.internal api.octostar.darkwinds.internal grafana.octostar.darkwinds.internal prometheus.octostar.darkwinds.internal shxo.click home.shxo.click fusion.shxo.click minio.shxo.click minio-api.shxo.click wss.shxo.click nifi.shxo.click kibana.shxo.click api.shxo.click grafana.shxo.click prometheus.shxo.click" ) > %HOSTS_FILE%.tmp
move /Y %HOSTS_FILE%.tmp %HOSTS_FILE%

REM Add new entries
for %%E in (
    "10.14.100.1 octostar.darkwinds.internal"
    "10.14.100.1 home.octostar.darkwinds.internal"
    "10.14.100.1 fusion.octostar.darkwinds.internal"
    "10.14.100.1 minio.octostar.darkwinds.internal"
    "10.14.100.1 minio-api.octostar.darkwinds.internal"
    "10.14.100.1 wss.octostar.darkwinds.internal"
    "10.14.100.1 nifi.octostar.darkwinds.internal"
    "10.14.100.1 kibana.octostar.darkwinds.internal"
    "10.14.100.1 api.octostar.darkwinds.internal"
    "10.14.100.1 grafana.octostar.darkwinds.internal"
    "10.14.100.1 prometheus.octostar.darkwinds.internal"
    "10.14.100.1 shxo.click"
    "10.14.100.1 home.shxo.click"
    "10.14.100.1 fusion.shxo.click"
    "10.14.100.1 minio.shxo.click"
    "10.14.100.1 minio-api.shxo.click"
    "10.14.100.1 wss.shxo.click"
    "10.14.100.1 nifi.shxo.click"
    "10.14.100.1 kibana.shxo.click"
    "10.14.100.1 api.shxo.click"
    "10.14.100.1 grafana.shxo.click"
    "10.14.100.1 prometheus.shxo.click"
) do (
    echo %%~E>> %HOSTS_FILE%
)

echo Hosts entries for Octostar and shxo.click have been added.
endlocal

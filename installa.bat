@echo off
rem senza enabledelayedexpansion: toglierebbe i ! dai percorsi (C:\Users\Ciao!\...)
setlocal
title DagaDyn - Installazione

rem ==================================================================
rem  Copia l'estensione nella cartella Plugins di ogni versione di
rem  SketchUp trovata. Le impostazioni non si toccano: stanno
rem  in %APPDATA%\DagaDyn\settings.json, fuori dall'estensione.
rem  Per distribuirla agli altri: ruby tools\crea_rbz.rb (pacchetto .rbz).
rem ==================================================================

set "SRC=%~dp0"
if "%SRC:~-1%"=="\" set "SRC=%SRC:~0,-1%"

echo.
echo  ============================================
echo    DagaDyn  -  copia verso SketchUp
echo  ============================================
echo.
echo  Sorgente: %SRC%

rem --- i file sorgente ci sono tutti? ---------------------------------
set "MISSING="
for %%F in (dagadyn.rb dagadyn\main.rb dagadyn\panel.html dagadyn\LICENSE dagadyn\icons dagadyn\lang dagadyn\lib\config.rb) do (
  if not exist "%SRC%\%%F" (
    echo  [X] Manca nella sorgente: %%F
    set "MISSING=1"
  )
)
if defined MISSING (
  echo.
  echo      Installazione annullata.
  echo.
  pause
  exit /b 1
)

rem --- SketchUp aperto? Caricherebbe ancora la versione vecchia -------
tasklist /FI "IMAGENAME eq SketchUp.exe" 2>nul | find /I "SketchUp.exe" >nul
if not errorlevel 1 (
  echo.
  echo  [ATTENZIONE] SketchUp risulta APERTO.
  echo      I file verranno copiati lo stesso, ma per vedere le modifiche
  echo      devi chiudere e riaprire SketchUp.
)

rem --- una passata per ogni versione installata -----------------------
set "FOUND=0"
for /d %%V in ("%APPDATA%\SketchUp\SketchUp *") do (
  if exist "%%~fV\SketchUp\Plugins\" (
    set "FOUND=1"
    call :install "%%~fV\SketchUp\Plugins"
  )
)

if "%FOUND%"=="0" (
  echo.
  echo  [X] Nessuna cartella Plugins di SketchUp trovata in:
  echo      %APPDATA%\SketchUp
  echo      Copia i file a mano oppure controlla che SketchUp sia installato.
  echo.
  pause
  exit /b 1
)

echo.
echo  Fatto. Riavvia SketchUp per caricare la nuova versione.
echo.
pause
exit /b 0

rem ====================================================================
:install
set "DST=%~1"
set "EXT=%DST%\dagadyn"
echo.
echo  --^> %DST%

rem dagadyn_dev.rb carica DagaDyn dai sorgenti: con una copia installata
rem accanto, l'estensione si registrerebbe due volte. Si salta.
if exist "%DST%\dagadyn_dev.rb" (
  echo      [SALTATA] c'e' dagadyn_dev.rb: questa SketchUp carica gia' i sorgenti.
  echo      Per installare la copia, togli prima dagadyn_dev.rb.
  goto :eof
)

if not exist "%EXT%" mkdir "%EXT%"
copy /Y "%SRC%\dagadyn.rb"          "%DST%\" >nul && echo      dagadyn.rb       aggiornato
copy /Y "%SRC%\dagadyn\main.rb"     "%EXT%\" >nul && echo      main.rb          aggiornato
copy /Y "%SRC%\dagadyn\panel.html"  "%EXT%\" >nul && echo      panel.html       aggiornato
copy /Y "%SRC%\dagadyn\LICENSE"     "%EXT%\" >nul && echo      LICENSE          aggiornata
xcopy /E /I /Y /Q "%SRC%\dagadyn\icons" "%EXT%\icons\" >nul && echo      icons\           aggiornate
xcopy /E /I /Y /Q "%SRC%\dagadyn\lang"  "%EXT%\lang\"  >nul && echo      lang\            aggiornate ^(traduzioni^)
rem lib\ si ricopia da zero: un file tolto dalla sorgente non deve restare installato
if exist "%EXT%\lib" rmdir /S /Q "%EXT%\lib"
xcopy /E /I /Y /Q "%SRC%\dagadyn\lib"   "%EXT%\lib\"   >nul && echo      lib\             aggiornata ^(codice^)

goto :eof

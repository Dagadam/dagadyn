@echo off
setlocal
rem ==================================================================
rem  Tutte le prove di DagaDyn, senza SketchUp (e' simulata).
rem  Vuole Ruby 3.2; la prova delle curve vuole anche Node.js.
rem  Alla fine scrive TUTTO OK, oppure quali prove sono fallite.
rem ==================================================================
cd /d "%~dp0.."

set "FAIL="
for %%T in (test_engine test_link test_curves) do (
  echo.
  echo  === %%T
  ruby tools\%%T.rb
  if errorlevel 1 (
    echo  [X] %%T fallita
    call set "FAIL=%%FAIL%% %%T"
  )
)

echo.
if defined FAIL (
  echo  FALLITE:%FAIL%
  exit /b 1
)
echo  TUTTO OK
exit /b 0

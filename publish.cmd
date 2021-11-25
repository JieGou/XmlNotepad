@echo off
cd %~dp0
SET ROOT=%~dp0
set DRIVE=%~dd0
set WINGET_SRC=%ROOT%..\winget-pkgs
for /f "usebackq" %%i in (`xsl -e -s src\Version\version.xsl src\Version\version.props`) do (
    set VERSION=%%i
)

set WINGET=1

echo ### Publishing version %VERSION%...
where sed > nul 2>&1
if ERRORLEVEL 1 goto :nosed
if not EXIST publish goto :nobits
if not EXIST src\XmlNotepadSetup\bin\Release\XmlNotepadSetup.msi goto :nomsi
if EXIST src\XmlNotepadSetup\bin\Release\XmlNotepadSetup.zip del src\XmlNotepadSetup\bin\Release\XmlNotepadSetup.zip
if "%LOVETTSOFTWARE_STORAGE_CONNECTION_STRING%" == "" goto :nokey

where wingetcreate > nul 2>&1
if ERRORLEVEL 1 winget install wingetcreate

copy /y src\Updates\Updates.xml publish\
if ERRORLEVEL 1 goto :eof
copy /y src\Updates\Updates.xslt publish\
if ERRORLEVEL 1 goto :eof
copy /y src\Updates\Updates.xsd publish\
if ERRORLEVEL 1 goto :eof
copy /y src\Updates\Updates.xml src\XmlNotepadSetup\bin\Release\
if ERRORLEVEL 1 goto :eof
copy /y src\Updates\Updates.xslt src\XmlNotepadSetup\bin\Release\
if ERRORLEVEL 1 goto :eof
copy /y src\Updates\Updates.xsd src\XmlNotepadSetup\bin\Release\
if ERRORLEVEL 1 goto :eof
if exist publish\XmlNotepadSetup.zip del publish\XmlNotepadSetup.zip
pwsh -command "Compress-Archive -Path src\XmlNotepadSetup\bin\Release\* -DestinationPath publish\XmlNotepadSetup.zip"

if not EXIST src\XmlNotepadPackage\AppPackages\%VERSION%\XmlNotepadPackage_%VERSION%_Test\XmlNotepadPackage_%VERSION%_AnyCPU.msixbundle goto :noappx

echo Binaries to publish:
echo %ROOT%publish\XmlNotepadSetup.zip
echo %ROOT%src\XmlNotepadPackage\AppPackages\%VERSION%\XmlNotepadPackage_%VERSION%_Test\XmlNotepadPackage_%VERSION%_AnyCPU.msixbundle
set /p response=Please publish github release using the above binaries and press ENTER to continue...

echo Uploading ClickOnce installer to XmlNotepad
call AzurePublishClickOnce.cmd %~dp0publish downloads/XmlNotepad "%LOVETTSOFTWARE_STORAGE_CONNECTION_STRING%"
if ERRORLEVEL 1 goto :uploadfailed

echo ============ Done publishing ClickOnce installer to XmlNotepad ==============
 
if "%WINGET%"=="0" goto :skipwinget

if not exist %WINGET_SRC% goto :nowinget

:winget
echo Syncing winget master branch
pushd %WINGET_SRC%\manifests\m\Microsoft\XMLNotepad
git checkout master
git pull
git fetch upstream master
git merge upstream/master
git push
popd

echo Preparing winget package
set TARGET=%WINGET_SRC%\manifests\m\Microsoft\XMLNotepad\%VERSION%\
if not exist %TARGET% mkdir %TARGET%
copy /y tools\Microsoft.XMLNotepad*.yaml  %TARGET%
wingetcreate update Microsoft.XMLNotepad --version %VERSION% -o %WINGET_SRC% -u https://github.com/microsoft/XmlNotepad/releases/download/%VERSION%/XmlNotepadPackage_%VERSION%_AnyCPU.msixbundle
if ERRORLEVEL 1 goto :eof

pushd %TARGET%
winget validate .
winget install -m .
if ERRORLEVEL 1 goto :installfailed

git checkout -b "clovett/xmlnotepad_%VERSION%"
git add *
git commit -m "new XML Noteapd version %VERSION%"
git push -u origin "clovett/xmlnotepad_%VERSION%"

echo =============================================================================================================
echo Please create Pull Request for the new "clovett/xmlnotepad_%VERSION%" branch.

call gitweb
goto :eof

:nobits
echo 'publish' folder not found, please run Solution/Publish first.
exit /b 1

:nomsi
echo 'XmlNotepadSetup\bin\Release\XmlNotepadSetup.msi' not found, please use src\XmlNotepadSetup.sln to build the msi.
exit /b 1

:nokey
echo Please set your LOVETTSOFTWARE_STORAGE_CONNECTION_STRING
exit /b 1

:noappx
echo Please build the .msixbundle using src\XmlNotepadSetup.sln XmlNotepadPackage project, publish/create appx packages.
exit /b 1

:nosed
echo Missing sed.exe tool, please add c:\Program Files\Git\usr\bin to your PATH
exit /b 1

:installfailed
echo winget install failed
exit /b 1

:nowinget
echo Please clone git@github.com:lovettchris/winget-pkgs.git into %WINGET_SRC%
exit /b 1

:skipwinget
echo Skipping winget setup
exit /b 1

:uploadfailed
echo Upload to Azure failed.
exit /b 1
cd ..
powershell -ExecutionPolicy Bypass -File scripts/clean.ps1
dotnet restore
pause
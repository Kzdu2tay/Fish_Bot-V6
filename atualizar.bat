@echo off
cd /d "C:\Users\tayro\Downloads\IA_ROBLOX\Fish_Bot-V6"

echo.
echo ==========================================
echo   FISCH BOT - Git Update
echo ==========================================
echo.

set /p MSG="Mensagem do commit (ex: v8: melhoria shake): "

git add .
git commit -m "%MSG%"
git push

echo.
echo ==========================================
if %ERRORLEVEL% == 0 (
    echo   Atualizado com sucesso!
) else (
    echo   Algo deu errado - veja o erro acima
)
echo ==========================================
echo.
pause
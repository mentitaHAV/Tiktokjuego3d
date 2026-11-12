@echo off
rem Puente de TikTok: escribe los likes y regalos en eventos.jsonl para que el juego los lea.
cd /d "%~dp0puente"
if not exist node_modules call npm install
node tiktok.js %*
pause

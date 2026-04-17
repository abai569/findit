@echo off
chcp 65001 >nul
cls
echo ========================================
echo   物品管家 - 上传到 GitHub
echo ========================================
echo.
echo 检测到你的电脑未安装 Git
echo.
echo 请选择以下方式之一：
echo.
echo 【推荐】使用 GitHub Desktop（图形界面）
echo   1. 访问：https://desktop.github.com
echo   2. 下载并安装
echo   3. 打开后选择：Add -> Add Existing Repository
echo   4. 选择此文件夹：C:\Users\57064\app\findit
echo   5. 点击 Publish repository
echo.
echo 【或者】安装 Git 后重新运行此脚本
echo   下载地址：https://git-scm.com/download/win
echo.
echo ========================================
echo.
echo 按任意键打开 GitHub Desktop 下载页面...
pause >nul
start https://desktop.github.com
exit

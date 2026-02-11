SET|HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders|Desktop|ExpandString|C:\RH\INBOX\DESKTOP_SWEEP
SET|HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders|Desktop|String|C:\RH\INBOX\DESKTOP_SWEEP
SET|HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders|{374DE290-123F-4565-9164-39C4925E467B}|ExpandString|C:\RH\INBOX\DOWNLOADS
SET|HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders|{374DE290-123F-4565-9164-39C4925E467B}|String|C:\RH\INBOX\DOWNLOADS
SET|HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders|My Pictures|ExpandString|C:\RH\LIFE\MEDIA\PHOTOS
SET|HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders|My Pictures|String|C:\RH\LIFE\MEDIA\PHOTOS
SET|HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders|Personal|ExpandString|C:\RH\LIFE\DOCS
SET|HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders|Personal|String|C:\RH\LIFE\DOCS
SET|HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders|My Video|ExpandString|C:\RH\LIFE\MEDIA\VIDEOS
SET|HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders|My Video|String|C:\RH\LIFE\MEDIA\VIDEOS
ACTION|ExplorerRestart=Yes
TEST|Download|C:\RH\INBOX\DOWNLOADS\phase6b2_download_test_20260207_195534.txt
CREATED_DIR|C:\RH\LIFE\MEDIA\PHOTOS\Screenshots
TEST|Screenshot|C:\RH\LIFE\MEDIA\PHOTOS\Screenshots\Screenshot_phase6b2_test_20260207_195534.png
ACTION|ScreenshotIntakeMove|C:\RH\INBOX\SCREENSHOTS\Screenshot_phase6b2_test_20260207_195534.png

# Zoomicon.Downloader.Delphi
Downloader for Delphi

Originated in the context of the [READ-COM Application](https://github.com/Zoomicon/READCOM_App) project.

READ-COM App now [uses](https://github.com/Zoomicon/READCOM_App/blob/fa841b5a1b99a9ce46bda70c754378d58539892d/App/Views/READCOM.Views.Main.pas#L1167) TUrlStream instead (introduced in recent Delphi versions).

However, test cases do pass, so feel free to experiment with TDownloader and TFileDownloader, as shown in the Test project.

## Dependencies

### Boss Packages
need to install via [Boss Package Manager](https://github.com/HashLoad/boss/releases/latest) (you can use [Boss Experts](https://getitnow.embarcadero.com/boss-experts/) from GetIt to see a UI for it in the IDE)
* [Zoomicon.Cache.Delphi](https://github.com/Zoomicon/Zoomicon.Cache.Delphi)

see [boss.json](https://github.com/Zoomicon/Zoomicon.Downloader.Delphi/blob/master/boss.json)
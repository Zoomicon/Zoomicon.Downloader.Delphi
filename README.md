# Zoomicon.Downloader.Delphi 
Downloader for Delphi

Originated in the context of the [READ-COM Application](https://github.com/Zoomicon/READCOM_App) project.

READ-COM App now [uses](https://github.com/Zoomicon/READCOM_App/blob/fa841b5a1b99a9ce46bda70c754378d58539892d/App/Views/READCOM.Views.Main.pas#L1167) TUrlStream instead (introduced in recent Delphi versions).

However, test cases do pass, so feel free to experiment with TDownloader and TFileDownloader, as shown in the Test project.

## Usage
Can opt to install via [Boss Package Manager](https://github.com/HashLoad/boss/releases/latest) (you can use [Boss Experts](https://getitnow.embarcadero.com/boss-experts/) from GetIt to see a UI for it in the IDE).

You just need to add as dependency the GitHub site's url: [https://github.com/Zoomicon/Zoomicon.Downloader.Delphi](https://github.com/Zoomicon/Zoomicon.Downloader.Delphi)

## Dependencies

### Boss Packages
To build from source code you need to install the following, ideally via [Boss Package Manager](https://github.com/HashLoad/boss/releases/latest) (you can use [Boss Experts](https://getitnow.embarcadero.com/boss-experts/) from GetIt to see a UI for it in the IDE)
* [Zoomicon.Cache.Delphi](https://github.com/Zoomicon/Zoomicon.Cache.Delphi)

see [boss.json](https://github.com/Zoomicon/Zoomicon.Downloader.Delphi/blob/master/boss.json)

*Note:*

Using a separate boss.json in the Source subfolder apart from the one at the top-level of the git repository.

This is to be able to use Boss Experts to update dependencies (aka Zoomicon.Cache.Delphi) when one wants to work on the source code of that project.

Also, not using "package" wrapping node in that second boss.json, since Boss-Experts GUI doesn't support reading dependencies with it


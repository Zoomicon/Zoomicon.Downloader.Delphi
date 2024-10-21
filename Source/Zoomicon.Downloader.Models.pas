//Project: Zoomicon.Downloader (https://github.com/Zoomicon/Zoomicon.Downloader.Delphi)
//Author: George Birbilis (http://Zoomicon.com)
//Description: Downloader models

unit Zoomicon.Downloader.Models;

interface
  uses
    System.Classes, //for TThread
    System.Net.URLClient, //for TURI
    System.SyncObjs, //for TWaitResult
    //
    Zoomicon.Cache.Models; //for IContentCache

  const
    STATUS_OK = 200; //HTTP OK (https://en.wikipedia.org/wiki/List_of_HTTP_status_codes)
    STATUS_NOT_FOUND = 404; //HTTP NOT FOUND (https://en.wikipedia.org/wiki/HTTP_404)
    //
    DEFAULT_DOWNLOAD_TIMEOUT = Cardinal(10000); //10 sec (can also use INFINITE)

  type
    TDownloadProgressEvent = procedure(const Sender: TObject; const TotalElapsedTime: Cardinal; const Speed: Integer; const TotalReadCount: Int64; const TotalContentLength: Int64; var Abort: Boolean) of object;
    TDownloadTerminationEvent = procedure(const Sender: TObject; const Status: Integer) of object;
    TDownloadCompletionEvent = procedure(const Sender: TObject; Data: TStream) of object;

    IDownloader = interface
      ['{1C17622E-9D01-4042-B3CE-47A53C060A05}']
      procedure Initialize(const TheContentURI: TURI; const Data: TStream; const TheContentCache: IContentCache = nil;  const AutoStart: Boolean = true; const TheStartPosition: Int64 = 0; const TheEndPosition: Int64 = 0);

      procedure Start;
      function WaitForDownload(const Timeout: Cardinal = DEFAULT_DOWNLOAD_TIMEOUT): TWaitResult;

      procedure SetPaused(const Value: Boolean);
      function IsTerminated: Boolean;

      property Terminated: Boolean read IsTerminated;
    end;

    IFileDownloader = interface(IDownloader)
      ['{79AA850A-A875-4D07-B2D0-CFDDADEE1847}']
      procedure Initialize(const TheContentURI: TURI; const Filepath: String; const TheContentCache: IContentCache = nil; const AutoStart: Boolean = true; const TheStartPosition: Int64 = 0; const TheEndPosition: Int64 = 0);
    end;

implementation

end.

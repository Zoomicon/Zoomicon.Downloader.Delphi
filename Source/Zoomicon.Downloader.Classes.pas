//Project: Zoomicon.Downloader (https://github.com/Zoomicon/Zoomicon.Downloader.Delphi)
//Author: George Birbilis (http://Zoomicon.com)
//Description: Downloader implementations

unit Zoomicon.Downloader.Classes;

interface
  uses
    System.Classes, //for TThread
    System.Net.URLClient, //for TURI
    System.SyncObjs, //for TEvent, TWaitResult
    //
    Zoomicon.Cache.Models, //for IContentCache
    Zoomicon.Downloader.Models; //for IDownloader

  var
    SleepTimeMS: integer = 1;

  type

    TDownloader = class;

    TDownloaderThread = class(TThread)
      protected
        FDownloader: TDownloader;

      public
        constructor Create(const TheDownloader: TDownloader);
        destructor Destroy; override;

        procedure Execute; override;

        function WaitForTermination(const Timeout: Cardinal = DEFAULT_DOWNLOAD_TIMEOUT): TWaitResult;
        procedure SetTerminationEvent;

        property Downloader: TDownloader read FDownloader write FDownloader;
    end;

    TDownloader = class(TComponent, IDownloader)
      protected
        FContentCache: IContentCache;
        FOnlyFallbackCache: Boolean;
        FDownloaderThread: TDownloaderThread;
        FDownloaderThreadTerminationEvent: TEvent; //for other threads synchronization with downloader thread

        FLastSessionElapsedTime, FTotalElapsedTime, FSessionStartTime: Cardinal;
        FLastSessionReadCount, FTotalReadCount, FTotalContentLength, FStartPosition, FEndPosition: Int64;
        FShouldResume: Boolean;

        FResumable: Boolean;
        FPaused: Boolean;

        FHeaderAccept: String;

        FContentURIstr: String;
        FData: TStream;

        FOnDownloadProgress: TDownloadProgressEvent;
        FOnDownloadTerminated: TDownloadTerminationEvent;
        FOnDownloadComplete: TDownloadCompletionEvent;

        function GetContentURI: TURI;

        function Download(const StartPosition, EndPosition: Int64): integer; overload; virtual; //returns HTTP status code
        procedure ReceiveHandler(const Sender: TObject; ContentLength, ReadCount: Int64; var Abort: Boolean);
        function Execute: integer; virtual; //returns HTTP status code //called by TDownloaderThread

      public
        constructor Create(AOwner: TComponent); overload; override;
        constructor Create(AOwner: TComponent; const TheContentURI: TURI; const TheData: TStream; const TheContentCache: IContentCache = nil; const AutoStart: Boolean = false; const TheStartPosition: Int64 = 0; const TheEndPosition: Int64 = 0); reintroduce; overload; virtual; //TODO: see why we need to use "reintroduce" here even though we have overriden "constructor Create(AOwner: TComponent)" which the compiler was complaining this method was hiding
        procedure Initialize(const TheContentURI: TURI; const TheData: TStream; const TheContentCache: IContentCache = nil; const AutoStart: Boolean = false; const TheStartPosition: Int64 = 0; const TheEndPosition: Int64 = 0);
        destructor Destroy; override;

        procedure Start; virtual;
        function WaitForDownload(const Timeout: Cardinal = DEFAULT_DOWNLOAD_TIMEOUT): TWaitResult;

        procedure SetPaused(const Value: Boolean);
        function IsTerminated: Boolean;

        class function GetUriWithFallbackCache(const AOwner: TComponent; const Uri: string; const Timeout: Cardinal = DEFAULT_DOWNLOAD_TIMEOUT): TMemoryStream;

      published
        property ContentCache: IContentCache read FContentCache write FContentCache;
        property OnlyFallbackCache: Boolean read FOnlyFallbackCache write FOnlyFallbackCache default false;
        property DownloaderThreadTerminationEvent: TEvent read FDownloaderThreadTerminationEvent;
        property Resumable: Boolean read FResumable write FResumable;
        property Paused: Boolean read FPaused write SetPaused;
        property Terminated: Boolean read IsTerminated;

        property HeaderAccept: String read FHeaderAccept write FHeaderAccept;
        //TODO: consider also adding Header properties for AcceptCharSet, AcceptEncoding, AcceptLanguage, ContentType, UserAgent

        property ContentURI: TURI read GetContentURI;
        property Data: TStream read FData;

        property TotalElapsedtime: Cardinal read FTotalElapsedTime;
        property TotalReadCount: Int64 read FTotalReadCount;
        property TotalContentLength: Int64 read FTotalContentLength;

        property OnDownloadProgress: TDownloadProgressEvent write FOnDownloadProgress;
        property OnDownloadTerminated: TDownloadTerminationEvent write FOnDownloadTerminated;
        property OnDownloadComplete: TDownloadCompletionEvent write FOnDownloadComplete;
    end;

    TFileDownloader = class(TDownloader, IFileDownloader)
      protected
        FFilepath: String;
        function Execute: integer; override; //returns HTTP status code //called by TDownloaderThread

      public
        constructor Create(AOwner: TComponent; const TheContentURI: TURI; const TheFilepath: String; const TheContentCache: IContentCache = nil; const AutoStart: Boolean = false; const TheStartPosition: Int64 = 0; const TheEndPosition: Int64 = 0); overload;
        procedure Initialize(const TheContentURI: TURI; const TheFilepath: String; const TheContentCache: IContentCache = nil; const AutoStart: Boolean = false; const TheStartPosition: Int64 = 0; const TheEndPosition: Int64 = 0); overload;
        destructor Destroy; override;

        procedure Start; override;

      published
        property Filepath: String read FFilepath write FFilepath;
    end;

  var
    DefaultFileCache: IFileCache;

  procedure Register;

implementation
uses
  {$IFDEF DEBUG}
    {$IF DEFINED(MSWINDOWS)}
    Winapi.Windows, //for OutputDebugString //TODO: change to use some logging library
    {$endif}
  {$ENDIF}
  System.IOUtils, //for TPath, TDirectory
  System.NetConsts, //to expand inline THTTPClient.SetAccept
  System.Net.HttpClient, //for THTTPClient
  System.SysUtils, //for fmOpenWrite, fmShareDenyNone
  //
  Zoomicon.Cache.Classes; //for TFileCache

{$REGION 'TDownloaderThread'}

{$region 'Lifecyle management'}

constructor TDownloaderThread.Create(const TheDownloader: TDownloader);
begin
  inherited Create(true); //Create suspended
  //FreeOnTerminate := false; //this is the default

  FDownloader := TheDownloader;
end;

destructor TDownloaderThread.Destroy;
begin
  SetTerminationEvent; //notify any threads waiting on our event object
  inherited; //do last
end;

{$endregion}

procedure TDownloaderThread.Execute; //returns HTTP status code
begin
  try
    ReturnValue := Downloader.Execute; //return HTTP status code
  finally
    SetTerminationEvent; //notify any threads waiting on our event object
  end;
end;

function TDownloaderThread.WaitForTermination(const Timeout: Cardinal = DEFAULT_DOWNLOAD_TIMEOUT): TWaitResult;
begin
  if Assigned(FDownloader) then
    begin
    var TerminationEvent := FDownloader.DownloaderThreadTerminationEvent;
    if Assigned(TerminationEvent) then
      exit(TerminationEvent.WaitFor(Timeout));
    end
  else
    exit(TWaitResult.wrError);

  result := TWaitResult.wrAbandoned;
end;

procedure TDownloaderThread.SetTerminationEvent;
begin
  if Assigned(FDownloader) then
    begin
    var TerminationEvent := FDownloader.DownloaderThreadTerminationEvent;
    if Assigned(TerminationEvent) then
      TerminationEvent.SetEvent;
    end;
end;

{$ENDREGION}

{$REGION 'TDownloader'}

{$region 'Lifecycle management'}

constructor TDownloader.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
end;

constructor TDownloader.Create(AOwner: TComponent; const TheContentURI: TURI; const TheData: TStream; const TheContentCache: IContentCache = nil; const AutoStart: Boolean = false; const TheStartPosition: Int64 = 0; const TheEndPosition: Int64 = 0);
begin
  inherited Create(AOwner);
  Initialize(TheContentURI, TheData, TheContentCache, AutoStart, TheStartPosition, TheEndPosition);
end;

procedure TDownloader.Initialize(const TheContentURI: TURI; const TheData: TStream; const TheContentCache: IContentCache = nil; const AutoStart: Boolean = false; const TheStartPosition: Int64 = 0; const TheEndPosition: Int64 = 0);
begin
  FContentCache := TheContentCache;

  FDownloaderThread := TDownloaderThread.Create(self);
  FDownloaderThreadTerminationEvent := TEvent.Create();

  FContentURIstr := TheContentURI.ToString;
  FData := TheData;

  FStartPosition := TheStartPosition;
  FEndPosition := TheEndPosition;

  FLastSessionReadCount := TheStartPosition;

  if AutoStart then
    Start;
end;

destructor TDownloader.Destroy;
begin
  FreeAndNil(FDownloaderThread); //this will invoke TerminationEvent (for other waiting threads)
  FreeAndNil(FDownloaderThreadTerminationEvent);

  inherited; //do last
end;

{$endregion}

function TDownloader.IsTerminated: Boolean;
begin
  result := Assigned(FDownloaderThread) and FDownloaderThread.CheckTerminated; //TODO: maybe should return true if not Assigned(FDownloaderThread)
end;

procedure TDownloader.Start;
begin
  if (not FDownloaderThread.Started) then
    FDownloaderThread.Start;
  Paused := false;
end;

function TDownloader.WaitForDownload(const Timeout: Cardinal): TWaitResult;
begin
  if Assigned(FDownloaderThread) then
    result := FDownloaderThread.WaitForTermination(Timeout)
  else
    result := TWaitResult.wrAbandoned;
end;

function TDownloader.Execute: Integer; //returns HTTP status code //called by TDownloaderThread

  function FetchFromCache: Integer;
  begin
    var CachedData := FContentCache.GetContent(FContentURIstr);
    if Assigned(CachedData) then
    begin
      FData.CopyFrom(CachedData); //copy from CachedData to output stream
      FreeAndNil(CachedData); //free CachedData handle
      result := STATUS_OK;
    end
    else
      result := STATUS_NOT_FOUND;
  end;

begin
  //If requested URI is cached, return its data from there...
  if Assigned(FContentCache) and (not FOnlyFallbackCache) then
  begin
    result := FetchFromCache;
    if (result = STATUS_OK) then exit;
  end;

  //Download...
  result := Download(FStartPosition, FEndPosition);

  while (not FDownloaderThread.CheckTerminated) and FResumable do
  begin
    if FShouldResume then
    begin
      FShouldResume := False;
      FPaused := False;
      result := Download(FLastSessionReadCount, FEndPosition);
      {$IFDEF DEBUG}
        {$IF DEFINED(MSWINDOWS)}
        //var msg := IntToStr(result);
        //OutputDebugString(@msg); //TODO, doesn't seem to work, better use CodeSite instead
        {$ENDIF}
      {$ENDIF}
    end;

    Sleep(SleepTimeMS); //sleep a bit, being polite to other threads
  end;

  if (result <> STATUS_OK) then
  begin
    if (FetchFromCache = STATUS_OK) then
      exit(STATUS_OK) //only interested in STATUS_OK from fallback cache, not overriding failure result of downloader on fallback cache miss
  end
  else
    //If data was downloaded succesfully, can cache downloaded data with URI as key...
    if Assigned(FContentCache) then
      FContentCache.PutContent(FContentURIstr, FData); //copies from start of stream
end;

function TDownloader.GetContentURI: TURI;
begin
  result := TURI.Create(FContentURIstr);
end;

procedure TDownloader.SetPaused(const Value: Boolean);
begin
  if Value then
    FPaused := True
  else
    FShouldResume := True;
end;

function TDownloader.Download(const StartPosition, EndPosition: Int64): Integer; //this is called by Execute which is called by TDownloaderThread
begin
  var HttpClient := THTTPClient.Create;
  HttpClient.Accept := FHeaderAccept;
  HttpClient.OnReceiveData := ReceiveHandler;

  var StatusCode: Integer := 0; //e.g. HTTP_OK=200

  try
    FSessionStartTime := FDownloaderThread.GetTickCount;

    if FEndPosition = 0 then
      StatusCode := HttpClient.Get(FContentURIstr, FData).StatusCode
    else
    begin
      FData.Seek(StartPosition, TSeekOrigin.soBeginning);
      StatusCode := HttpClient.GetRange(FContentURIstr, StartPosition, EndPosition, FData).StatusCode; //synchronous-blocking call (executes ReceiveHandler callback periodically)
    end;

    if Assigned(FOnDownloadTerminated) then
      FOnDownloadTerminated(Self, StatusCode);

    if Assigned(FOnDownloadComplete) and (StatusCode = STATUS_OK) then
      FOnDownloadComplete(Self, FData);

  finally
    HttpClient.Free;
    result := StatusCode;
    FDownloaderThread.Terminate; //note that this method is running on that thread (called via its Execute method which calls our Execute)
  end;
end;

{ See: https://docwiki.embarcadero.com/Libraries/Sydney/en/System.Net.HttpClient.THTTPClient.OnReceiveData
    Occurs one or more times while your HTTP client receives response data for one or more requests,
    and it indicates the current progress of the response download for the specified request.
    The event handler of OnReceiveData receives the following parameters:
    - Sender is the HTTP request that triggered the response.
    - ContentLength is the expected length of the response, in number of bytes.
    - ReadCount is the length of the response data that has been downloaded so far, in number of bytes.
    - Abort is an incoming variable parameter the event handler can set to True to abort data reception.
}
procedure TDownloader.ReceiveHandler(const Sender: TObject; ContentLength, ReadCount: Int64; var Abort: Boolean);
begin
  var SessionTime := FDownloaderThread.GetTickCount - FSessionStartTime; //in msec

  FTotalElapsedTime := FLastSessionElapsedTime + SessionTime;
  FTotalReadCount := FLastSessionReadCount + ReadCount;
  FTotalContentLength := FLastSessionReadCount + ContentLength;

  //First send download progress...
  if Assigned(FOnDownloadProgress) then
  begin
    var DownloadSpeed: Integer;
    if SessionTime = 0 then
      DownloadSpeed := 0
    else
      DownloadSpeed := (ReadCount * 1000) div SessionTime; //doing *1000 since ElapsedTime is in msec

    FOnDownloadProgress(Self, FTotalElapsedTime, DownloadSpeed, FTotalReadCount, FTotalContentLength, Abort);
  end;

  //...then abort any further downloading if needed
  if FDownloaderThread.CheckTerminated or FPaused then
  begin
    FLastSessionElapsedTime := FTotalElapsedTime;
    FLastSessionReadCount := FTotalReadCount;
    Abort := true;
  end;
end;

{$ENDREGION}

{$REGION 'TFileDownloader'}

constructor TFileDownloader.Create(AOwner: TComponent; const TheContentURI: TURI; const TheFilePath: String; const TheContentCache: IContentCache = nil; const AutoStart: Boolean = false; const TheStartPosition: Int64 = 0; const TheEndPosition: Int64 = 0);
begin
  inherited Create(AOwner);
  Initialize(TheContentURI, TheFilePath, TheContentCache, AutoStart, TheStartPosition, TheEndPosition);
end;

destructor TFileDownloader.Destroy;
begin
  if Assigned(FDownloaderThread) then
  begin
    if FDownloaderThread.ReturnValue <> STATUS_OK then //If failed to download, delete partially downloaded file //TODO: maybe only do it when non-resumable?
      TFile.Delete(Filepath); //Note: must first do FreeAndNil to release handle to file, then delete it

    FreeAndNil(FDownloaderThread);
  end;

  FreeAndNil(FData); //when it's a TFileDownloader we weren't given a data stream, we created it, so have to free it

  inherited; //do last
end;

procedure TFileDownloader.Initialize(const TheContentURI: TURI; const TheFilepath: string; const TheContentCache: IContentCache = nil; const AutoStart: Boolean = false; const TheStartPosition: Int64 = 0; const TheEndPosition: Int64 = 0);
begin
  Filepath := TheFilepath; //this will call SetFilepath (don't just assign FFilePath)
  Initialize(TheContentURI, FData, TheContentCache, AutoStart, TheStartPosition, TheEndPosition);
end;

procedure TFileDownloader.Start;
begin
  //only create the output file when download is to be started
  TDirectory.CreateDirectory(ExtractFileDir(FFilepath)); //create any missing subdirectories
  FData := TFileStream.Create(FFilepath, fmCreate or fmOpenWrite {or fmShareDenyNone}); //overwrite any existing file //TODO: fmShareDenyNote probably needed for Android
  inherited;
end;

function TFileDownloader.Execute: integer; //returns HTTP status code //called by TDownloaderThread
begin
  result := 0;
  try
    result := inherited;
  finally
    FreeAndNil(FData); //when it's a TFileDownloader we weren't given a data stream, we created it, so have to free it
    if result <> STATUS_OK then //If failed to download, delete partially downloaded file //TODO: maybe only do it when non-resumable?
      TFile.Delete(Filepath); //Note: must first do FreeAndNil to release handle to file, then delete it
  end;
end;

{$ENDREGION}

{$REGION 'Helper methods'}

class function TDownloader.GetUriWithFallbackCache(const AOwner: TComponent; const Uri: string; const Timeout: Cardinal = DEFAULT_DOWNLOAD_TIMEOUT): TMemoryStream;
begin
  result := TMemoryStream.Create; //caller should free this
  var FDownloader := TDownloader.Create(AOwner, TURI.Create(Uri), result, DefaultFileCache, {AutoStart=}true);
  try
    FDownloader.OnlyFallbackCache := true; //would use this if we only wanted to fallback to cache in case of download errors / offline case
    FDownloader.WaitForDownload(Timeout); //Note: this can freeze the main thread
  finally
    FreeAndNil(FDownloader);
  end;
end;

{$ENDREGION}

{$REGION 'Registration'}

procedure RegisterSerializationClasses;
begin
  RegisterClasses([TDownloader, TFileDownloader]);
end;

procedure Register;
begin
  GroupDescendentsWith(TDownloader, TComponent);
  GroupDescendentsWith(TFileDownloader, TComponent);
  RegisterSerializationClasses;
  RegisterComponents('Zoomicon', [TDownloader, TFileDownloader]);
end;

{$ENDREGION}

initialization
  RegisterSerializationClasses; //don't call Register here, it's called by the IDE automatically on a package installation (fails at runtime)
  DefaultFileCache := TFileCache.Create;

finalization
  DefaultFileCache := nil; //reference counted (interface reference), so object it points to will be released automatically when its reference count drops to 0

end.


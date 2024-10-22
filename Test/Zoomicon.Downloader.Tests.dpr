program Zoomicon.Downloader.Tests;
{

  Delphi DUnit Test Project
  -------------------------
  This project contains the DUnit test framework and the GUI/Console test runners.
  Add "CONSOLE_TESTRUNNER" to the conditional defines entry in the project options
  to use the console test runner.  Otherwise the GUI test runner will be used by
  default.

}

{$IFDEF CONSOLE_TESTRUNNER}
  {$APPTYPE CONSOLE}
{$ENDIF}

uses
  DUnitTestRunner,
  Test.Zoomicon.Downloader in 'Test.Zoomicon.Downloader.pas',
  Zoomicon.Downloader.Classes in '..\Source\Zoomicon.Downloader.Classes.pas',
  Zoomicon.Downloader.Models in '..\Source\Zoomicon.Downloader.Models.pas';

{$R *.RES}

begin
  ReportMemoryLeaksOnShutdown := True; //added to check memory leaks on exit
  DUnitTestRunner.RunRegisteredTests;
end.


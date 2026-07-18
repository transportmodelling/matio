program TestMatio;

////////////////////////////////////////////////////////////////////////////////
//
// https://github.com/transportmodelling/matio
//
////////////////////////////////////////////////////////////////////////////////

{$APPTYPE CONSOLE}
{$STRONGLINKTYPES ON}

uses
  System.SysUtils,
  DUnitX.Loggers.Console,
  DUnitX.Loggers.Xml.JUnit,
  DUnitX.TestFramework,
  TestMatio.Formats in 'TestMatio.Formats.pas',
  TestMatio.Reader in 'TestMatio.Reader.pas',
  TestMatio.Reader.Text in 'TestMatio.Reader.Text.pas',
  TestMatio.Reader.Csv in 'TestMatio.Reader.Csv.pas',
  TestMatio.Reader.Minutp in 'TestMatio.Reader.Minutp.pas',
  TestMatio.Reader.Gen4 in 'TestMatio.Reader.Gen4.pas',
  TestMatio.Reader.OMX in 'TestMatio.Reader.OMX.pas',
  TestMatio.Reader.Cube in 'TestMatio.Reader.Cube.pas',
  TestMatio.Reader.Masked in 'TestMatio.Reader.Masked.pas',
  TestMatio.Matrix in 'TestMatio.Matrix.pas',
  TestMatio.RoundTrip in 'TestMatio.RoundTrip.pas',
  TestMatio.Enum in 'TestMatio.Enum.pas',
  TestMatio.IO in 'TestMatio.IO.pas';

begin
  try
    // Initialization
    TDUnitX.CheckCommandLine;
    TDUnitX.Options.XMLOutputFile := ExtractFilePath(ParamStr(0)) + 'TestMatio.xml';
    // Create the test Runner
    var Runner := TDUnitX.CreateRunner;
    Runner.UseRTTI := True;
    Runner.FailsOnNoAsserts := False;
    // Create loggers
    var ConsoleLogger := TDUnitXConsoleLogger.Create(false);
    var NunitLogger := TDUnitXXMLJUnitFileLogger.Create(TDUnitX.Options.XMLOutputFile);
    Runner.AddLogger(ConsoleLogger);
    Runner.AddLogger(NunitLogger);
    //Run tests
    var Results := Runner.Execute;
    if not Results.AllPassed then System.ExitCode := EXIT_ERRORS;
  except
    on E: Exception do
      System.Writeln(E.ClassName, ': ', E.Message);
  end;
end.

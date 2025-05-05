unit AutoZip;

interface

{$WARN SYMBOL_PLATFORM OFF}

uses
  Windows, Classes, Forms, StdCtrls, ExtCtrls,
  NexESCmps, AbArcTyp, AbZBrows, AbZipper, AbMeter, AbBase, AbBrowse,
  Abziptyp, Controls, BusinessSkinForm, bsSkinCtrls, bsSkinBoxCtrls, Translation;

type
  TZipForm = class(TForm)
    zipArchive: TAbZipper;
    NexESTile1: TbsSkinPanel;
    btnSelectAll: TbsSkinButton;
    btnClearAll: TbsSkinButton;
    btnZip: TbsSkinButton;
    bsBusinessSkinForm1: TbsBusinessSkinForm;
    pMain: TbsSkinPanel;
    pTop: TbsSkinPanel;
    laProgress: TbsSkinStdLabel;
    mtrArchive: TAbMeter;
    ChkList: TbsSkinCheckListBox;
    grpDestination: TbsSkinGroupBox;
    rbHardDrive: TbsSkinCheckRadioBox;
    procedure FormCreate(Sender: TObject);
    procedure btnSelectAllClick(Sender: TObject);
    procedure btnClearAllClick(Sender: TObject);
    procedure btnZipClick(Sender: TObject);
    procedure zipArchiveRequestBlankDisk(Sender: TObject; var Abort: Boolean);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure FormShow(Sender: TObject);
  private
    FIsArchive: boolean;
    FTempFolder: string;
    FIsZipping: Boolean;
    FBackupDB: string;

    procedure AddTablesToArchive;
    procedure AddHaspToArchive;
    procedure AddErrorLogToArchive;
    procedure AddArchiveFlagToArchive;
    procedure AddCompressedErrorLogToArchive;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Setup(AFileList: TStringList; IsArchive: Boolean);
    procedure SetAndShowModal(AFileList: TStringList; IsArchive: Boolean);
  end;

implementation

uses
  SysUtils, Dialogs, SharedFunctions, Config, HostHasp, HaspAPI, StStrL,
  SharedConstants, NexESConstants, Errors, ErrorLog, VDBIsam, dmSkins,
  NexESFunctions, DBSQLiteHelpers, SQLiteEncryption,
  {$IFDEF XEDITOR}
  XDriverServerHelper,
  {$ENDIF}
  NexVLM,
  DualLanguageMessage,
  HaspConstants, HaspErrorCodes;

{$R *.DFM}

const
   MAXFLOPPYBYTES = 1430000;
   MAXHARDDRIVEBYTES = 95000000;
   sBASEFILENAME = 'NX';
   sDEFAULTEXTENTION = '.ZIP';

   RandomSeedValue = 8872155;
   ImageFileName  = 'NEXESKEY.DAT';
   LiveFlagName = 'Live';
   TextFileExtension = '.txt';

   { The Drive Code for C: drive }
   DriveCode = 3;
   BackupPrefix = 'BACKUP_';

{ ============================================================================ }
constructor TZipForm.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  { Pause all Banned Replication types before going on to perform the task. }
  NexESVlmClient.PauseAllReplication;
end;

{ ============================================================================ }
destructor TZipForm.Destroy;
begin
  NexESVlmClient.ResumeAllReplication;
  inherited Destroy;
end;

{ ============================================================================ }
procedure TZipForm.FormShow(Sender: TObject);
begin
  {$IFDEF XEDITOR}
  SendXDriverFormVisited(ClassName);
  {$ENDIF}
end;

{ ============================================================================ }
procedure TZipForm.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  CanClose := not FIsZipping;
end;

{ ============================================================================ }
procedure TZipForm.FormCreate(Sender: TObject);
begin
  InitializeForm(Self, False);

  FIsArchive := False;
  FTempFolder := GetVAliasPath(TempAlias);
end;

{ ============================================================================ }
procedure TZipForm.Setup(AFileList: TStringList; IsArchive: Boolean);
var
  i: Integer;
  n: Integer;
  t: TNexESDataTables;
begin
  ChkList.Clear;

  { go through the list of all DB's and add to checklist }
  for t := LowestDataTable to HighestDataTable do
    ChkList.Items.Add(NexESDataTables[t].FileName);

  { check the ones that are in the list }
  if Assigned(AFileList) then
    for i := 0 to (AFileList.Count - 1) do
    begin
      n := ChkList.Items.IndexOf(ExtractFileWithoutExt(AFileList[i]));
      if n > -1 then
        ChkList.State[n] := cbChecked;
    end;

  FIsArchive := IsArchive;
end;

{ ============================================================================ }
procedure TZipForm.SetAndShowModal(AFileList: TStringList; IsArchive: Boolean );
begin
  Setup(AFileList, IsArchive);
  ShowModal;
end;

{ ============================================================================ }
procedure TZipForm.AddTablesToArchive;
var
  I: Integer;
  ErrorMsg: string;
  OldHostKey: Integer;
  Encryption: TSQLiteEncryption;
begin
  FBackupDB := '';
  Encryption := TSQLiteEncryption.Create(DataAlias, VSession.CurrentEncryption, VSession.CurrentHostKey);
  try
    { Initialize OldHostKey to connect to the source database }
    if Encryption.DatabaseEncryptionStatus = secEncrypted then
      OldHostKey := VSession.CurrentHostKey
    else
      OldHostKey := 0;

    { Copy selected tables  }
    for I := 0 to ChkList.Items.Count - 1 do
      if ChkList.State[i] = cbChecked then
      begin
        { Initialize full name of the target database if it is empty }
        if FBackupDB = '' then
          FBackupDB := GetVAliasPath(DataAlias) + BackupPrefix + DataAlias + DBFileExt;
        { Copy a table }
        if not CopyTableToNewDatabase(DataAlias, FBackupDB, ChkList.Items[I], OldHostKey,
          VSession.CurrentHostKey, OldHostKey <> 0, ErrorMsg, True)
        then
          raise Exception.Create(ErrorMsg);
      end;
  finally
    Encryption.Free;
  end;

  { Add target database file into archive if it is not empty }
  if FBackupDB <> '' then
    zipArchive.AddFiles(FBackupDB, faReadOnly + faHidden);
end;

{ ============================================================================ }
procedure TZipForm.AddHaspToArchive;
var
  ADataString: string;
  AHASPDataFields: array[ 1..NUMBER_STRING_FIELDS ] of string;
  i: Integer;
  AnImageFile: file of byte;

  { >>>>>>> Local Procedure <<<<<<< }
  procedure EncryptDecryptKeyData;
  var
    x: Integer;
    ARandomNumber: Integer;
  begin
    { encryption using exclusive ORs (XOR) with pseudo random numbers. }
    RandSeed := RandomSeedValue;

    for x := 1 to Length(ADataString) do begin
      ARandomNumber := Random( 256 );

      ADataString[x] := char( byte( ADataString[x] ) XOR ARandomNumber );
    end;
  end;
  { <<<<<<< Local Procedure >>>>>>> }

begin
  { This is all pretty much stolen from savekey. The result is a file compatible
    with loadkey. }
  with TNexESHasp.Instance do
  begin
    for i := 1 to NUMBER_STRING_FIELDS do
      if GetString( i, AHASPDataFields[i] ) <> 0 then
        ErrorDlg( neAutoFixError, neZipForm_AddHaspToArchive_CantReadHasp,
                  'Error reading data from hardware key.',   {ivde }
                  mtError, [mbOK], 0);

    ADataString := '';
    for i := 1 to NUMBER_STRING_FIELDS do
      ADataString := ADataString + AHASPDataFields[i] + WideDelimiter;

    { Now encrypt the data before saving. }
    EncryptDecryptKeyData;

    { Now we just need to save the string to the output file. }
    AssignFile(AnImageFile, (FTempFolder + ImageFileName));
    try
      Rewrite( AnImageFile );
      for i := 1 to length(ADataString) do
        Write(AnImageFile, byte(ADataString[i]));
    finally
      CloseFile( AnImageFile );
    end;
    zipArchive.AddFiles(FTempFolder + ImageFileName, faReadOnly + faHidden);
  end;
end;

{ ============================================================================ }
procedure TZipForm.AddErrorLogToArchive;
var
  sTemp: string;
begin
  sTemp := GetEXEDir + ErrorLogName;
  if FileExists( sTemp ) then
    zipArchive.AddFiles( sTemp, faReadOnly + faHidden );

  { Add old error log, if exists }
  sTemp := GetEXEDir + OldErrorLogName;
  if FileExists( sTemp ) then
    zipArchive.AddFiles( sTemp, faReadOnly + faHidden );
end;

{ ============================================================================ }
procedure TZipForm.AddCompressedErrorLogToArchive;
var
    SearchFileSpec,
      SearchSpec : string;
    PrevZipFiles : TStringList;
    I: Integer;
begin
    { Create new TStringList }
    PrevZipFiles := TStringList.Create;
    try
      { Get the previous Zip files }
      SearchSpec := GetEXEDir + AddBackSlashL(LogsFolderName) + OldErrorLogName;
      SearchFileSpec := ChangeFileExt(SearchSpec, Concat('.*', ZipFileExtension));
      GetFileList(SearchFileSpec,PrevZipFiles);
      for I := 0 to PrevZipFiles.Count - 1 do
        zipArchive.AddFiles( PrevZipFiles[I], faReadOnly + faHidden );
    finally
      PrevZipFiles.Free;
    end;
end;


{ ============================================================================ }
procedure TZipForm.AddArchiveFlagToArchive;
var
  ADataString: string;
  AListing: TStringList;
begin
  if FIsArchive then
    ADataString := ArchiveFlagName
  else
    ADataString := LiveFlagName;

  ADataString := FTempFolder + ADataString + TextFileExtension;
  AListing := TStringList.Create;
  try
    Dir( GetExeDir, '*.*', AListing, AllDirOptions );
    AListing.Add('');

    { I hate the hard coded number, but diskfree requires a byte instead of a drive letter }
    AListing.Add('Total space on Drive C: = ' + IntToStr(DiskSize( DriveCode )) );
    AListing.Add(' Free Space on Drive C: = ' + IntToStr(DiskFree( DriveCode )) );
    AListing.Add('');

    AListing.SaveToFile( ADataString );
    zipArchive.AddFiles( ADataString, faAnyFile );
  finally
    AListing.Free;
  end;
end;

{ ============================================================================ }
procedure TZipForm.zipArchiveRequestBlankDisk(Sender: TObject; var Abort: Boolean);
begin
  Abort := False;
  while FileExists(zipArchive.FileName) and not Abort do
    Abort := TransDisplayAndLogMessageDlg( 'Insert a blank, formatted disk into Drive A:',      {ivde}
                              mtInformation, [mbOK, mbCancel], 0 ) = ID_CANCEL;
end;

{ ============================================================================ }
procedure TZipForm.btnSelectAllClick(Sender: TObject);
var
  i: Integer;
begin
  LockWindowUpdate(ChkList.Handle);
  try
    { check to each item }
    for i := 0 to (ChkList.Items.Count - 1) do
      ChkList.State[i] := cbChecked;
  finally
    LockWindowUpdate(0);
  end;
end;

{ ============================================================================ }
procedure TZipForm.btnClearAllClick(Sender: TObject);
var
  i: Integer;
begin
  LockWindowUpdate(ChkList.Handle);
  try
    { uncheck to each item }
    for i := 0 to (ChkList.Items.Count - 1) do
      ChkList.State[i] := cbUnchecked;
  finally
    LockWindowUpdate(0);
  end;
end;

{ ============================================================================ }
procedure TZipForm.btnZipClick(Sender: TObject);
var
  sDrive: string;
  sTemp: string;
  dualLanguageErrorMessage: TDualLanguageMessage;
  firstPartOfErrorMessage: string;
const
  ZipFileAlreadyExists = 'The Zip file already exists. Overwrite?'; {ivde}
begin
  { set up for hard drive }
  sDrive := 'C:\';
  zipArchive.SpanningThreshold := MAXHARDDRIVEBYTES;

  { build the complete archive filespec }
  sTemp := sDrive + sBASEFILENAME + IntToStr(VSession.CurrentHostKey) + sDEFAULTEXTENTION;

  { Time to open it }
  if FileExists(sTemp) then
  begin
    dualLanguageErrorMessage := TDualLanguageMessage.Create;

    try
      firstPartOfErrorMessage := sCRLF + sTemp + sCRLF;
      dualLanguageErrorMessage.MessageInEnglishLanguage := firstPartOfErrorMessage + ZipFileAlreadyExists;
      dualLanguageErrorMessage.MessageInCurrentLanguage := firstPartOfErrorMessage + Translation.TTranslation.Instance.Translate(ZipFileAlreadyExists);

      if ErrorDlg(neAutoFixError, neZipForm_ZipButtonClick_OverwriteZip,
                dualLanguageErrorMessage,
                mtError, [mbYes,mbNo], 0 ) = mrNo then
        exit
      else
        DeleteFile(sTemp);
    finally
      FreeAndNil(dualLanguageErrorMessage);
    end;
  end;

  FIsZipping := True;
  try
    Screen.Cursor := crHourGlass;
    grpDestination.Visible := False;
    btnSelectAll.Enabled := False;
    btnClearAll.Enabled := False;
    btnZip.Enabled := False;
    try
      zipArchive.OpenArchive(sTemp);

      { Add the files in the checklist that are checked }
      AddTablesToArchive;

      { Add Hasp info }
      AddHaspToArchive;

      { Add errorlog }
      AddErrorLogToArchive;
      AddArchiveFlagToArchive;

      { Add the compressed error logs to the archive. }
      AddCompressedErrorLogToArchive;

      { Need to save the archive before closing to allow the spanning function
        to work correctly. }
      zipArchive.Save;
      zipArchive.CloseArchive;

      { This stuff has to go here because until the archive is closed, the files
        must still exist. AbZipper doesn't 'actually' add them until it closes... :( }
      DeleteFile(FTempFolder + ImageFileName);
      if FIsArchive then
        DeleteFile(FTempFolder + ArchiveFlagName + TextFileExtension)
      else
        DeleteFile(FTempFolder + LiveFlagName + TextFileExtension);
    finally
      if FBackupDB <> '' then
      begin
        VSession.GetDatabase(FBackupDB).Disconnect;
        DeleteFile(FBackupDB);
      end;
      DeleteFile(FBackupDB);
      grpDestination.Visible := True;
      btnSelectAll.Enabled := True;
      btnClearAll.Enabled := True;
      btnZip.Enabled := True;
      Screen.Cursor := crDefault;
    end;
    LogToErrorLogFile('', sTemp + ' ' +
                      'Created.');            {ivde}
    TransDisplayAndLogMessageDlg(sTemp + ' ' +
                    Translation.TTranslation.Instance.Translate('Created.'),   {ivde}
                    mtInformation, [mbOK], 0, HAS_BEEN_LOGGED );
  finally
    FIsZipping := False;
  end;
end;

end.

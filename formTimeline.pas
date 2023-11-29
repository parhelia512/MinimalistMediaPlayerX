{   Minimalist Media Player
    Copyright (C) 2021 Baz Cuda <bazzacuda@gmx.com>
    https://github.com/BazzaCuda/MinimalistMediaPlayer

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307, USA
}
unit formTimeline;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.ExtCtrls, Generics.Collections, Vcl.StdCtrls, Vcl.Imaging.pngimage;

type
  TTimelineForm = class(TForm)
    pnlCursor: TPanel;
    lblPosition: TPanel;
    imgTrashCan: TImage;
    procedure FormCreate(Sender: TObject);
    procedure pnlCursorMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure pnlCursorMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure pnlCursorMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure pnlCursorMouseEnter(Sender: TObject);
    procedure pnlCursorMouseLeave(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure FormKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
  strict private
    FDragging: boolean;
  private
    function getCursorPos: integer;
    procedure setCursorPos(const Value: integer);
  protected
    procedure CreateParams(var Params: TCreateParams);
  public
    property cursorPos: integer read getCursorPos write setCursorPos;
  end;

  TSegment = class(TPanel)
  strict private
    FDeleted:     boolean;
    FEndSS:       integer;
    FOldColor:    TColor;
    FSegDetails:  TLabel;
    FSegID:       TLabel;
    FSelected:    boolean;
    FStartSS:     integer;
    FTrashCan:    TImage;
  private
    function  getDuration: integer;
    procedure setSegID(const Value: string);
    function  getSegID: string;
    procedure setSegDetails;
    procedure setSelected(const Value: boolean);
  protected
    procedure doClick(Sender: TObject);
    procedure paint; override;
  public
    constructor create(const aStartSS: integer; const aEndSS: integer; const aDeleted: boolean = FALSE);
    property deleted:   boolean read FDeleted  write FDeleted;
    property duration:  integer read getDuration;
    property endSS:     integer read FEndSS    write FEndSS;
    property oldColor:  TColor  read FOldColor write FOldColor;
    property segID:     string  read getSegID  write setSegID;
    property selected:  boolean read FSelected write setSelected;
    property startSS:   integer read FStartSS  write FStartSS;
    property trashCan:  TImage  read FTrashCan;
  end;

  TTimeline = class(TObject)
  strict private
    FMax: integer;
    FMediaFilePath: string;
    FPosition: integer;
    FSegments: TList<TSegment>;
    FSelSeg: TSegment;
    function getMax: integer;
    function getPosition: integer;
    procedure setMax(const Value: integer);
    procedure setPosition(const Value: integer);
    function freeSegments: boolean;
  private
    constructor create;
    destructor  destroy; override;
    function clearFocus: boolean;
    function cutSegment(const aSegment: TSegment; const aCursorPos: integer): boolean;
    function delSegment(const aSegment: TSegment): boolean;
    function drawSegments: boolean;
    function getSegCount: integer;
    function initialSegment: boolean;
    function loadSegments: boolean;
    function log(aLogEntry: string): boolean;
    function processSegments: boolean;
    function restoreSegment(const aSegment: TSegment): boolean;
    function saveSegments: boolean;
    function segmentAtCursor: TSegment;
  public
    function keyHandled(key: WORD): boolean;
    property max: integer read getMax write setMax;
    property position: integer read getPosition write setPosition;
    property segCount: integer read getSegCount;
    property selSeg:   TSegment read FSelSeg write FSelSeg;
  end;

function focusTimeline: boolean;
function showTimeline(const Pt: TPoint; const aWidth: integer; const createNew: boolean = TRUE): boolean;
function shutTimeline: boolean;
function TL: TTimeline;

implementation

uses
  progressBar, mediaPlayer, dialogs, playlist, shellAPI, commonUtils, _debugWindow;

const
  NEARLY_BLACK = clBlack + $101010;

var
  timelineForm: TTimelineForm;
  gTL: TTimeline;

function execAndWait(const aCmdLine: string): boolean;
var
  ExecInfo: TShellExecuteInfo;
  exitCode: cardinal;
begin
  ZeroMemory(@ExecInfo, SizeOf(ExecInfo));
  with ExecInfo do
  begin
    cbSize := SizeOf(ExecInfo);
    fMask := SEE_MASK_NOCLOSEPROCESS;
    Wnd := 0;
    lpVerb := 'open';
    lpFile := 'ffmpeg';
    lpParameters := PChar(aCmdLine);
    lpDirectory := '';
    nShow := SW_HIDE;
  end;
  result := ShellExecuteEx(@ExecInfo);
  if result then
  begin
    if ExecInfo.hProcess <> 0 then // no handle if the process was activated by DDE
    begin
      repeat
        if MsgWaitForMultipleObjects(1, ExecInfo.hProcess, FALSE, INFINITE, QS_ALLINPUT) = (WAIT_OBJECT_0 + 1) then
          application.processMessages
        else
          BREAK;
      until FALSE;
      getExitCodeProcess(execInfo.hProcess, exitCode);
      result := exitCode = 0;
      CloseHandle(ExecInfo.hProcess);
    end;
  end;
end;

function focusTimeline: boolean;
begin
  case timeLineForm = NIL of TRUE: EXIT; end;
  setForegroundWindow(timelineForm.handle); // so this window also receives keyboard keystrokes
end;

function showTimeline(const Pt: TPoint;  const aWidth: integer; const createNew: boolean = TRUE): boolean;
begin
  case (timelineForm = NIL) and createNew of TRUE: timelineForm := TTimelineForm.create(NIL); end;
  case timelineForm = NIL of TRUE: EXIT; end; // createNew = FALSE and there isn't a current timeline window. Used for repositioning the window when the main UI moves or resizes.

  timelineForm.width  := aWidth;
  timelineForm.height := 54;

  timelineForm.show;
  winAPI.Windows.setWindowPos(timelineForm.handle, HWND_TOP, Pt.X, Pt.Y, 0, 0, SWP_SHOWWINDOW + SWP_NOSIZE);
end;

function shutTimeline: boolean;
begin
  timelineForm.hide;
end;

function TL: TTimeline;
begin
  case gTL = NIL of TRUE: gTL := TTimeline.create; end;
  result := gTL;
end;

var nextColor: integer = 0;
function generateRandomEvenDarkerSoftColor: TColor;
// chatGPT
var
  darkerSoftColors: array of TColor;
begin
  // Define an array of even darker soft colors
  SetLength(darkerSoftColors, 6);
  darkerSoftColors[0] := RGB(80, 80, 80);   // Very Dark Gray
  darkerSoftColors[1] := RGB(70, 70, 70);   // Very Dark Silver
  darkerSoftColors[2] := RGB(60, 60, 60);   // Very Dark Platinum
  darkerSoftColors[3] := RGB(50, 50, 50);   // Very Dark Snow
  darkerSoftColors[4] := RGB(40, 40, 40);   // Very Dark Ivory
  darkerSoftColors[5] := RGB(30, 30, 30);   // Extremely Dark Gray

  result := darkerSoftColors[nextColor];
  inc(nextColor);
  case nextColor > 5 of TRUE: nextColor := 0; end;
end;

{$R *.dfm}

{ TTimelineForm }

procedure TTimelineForm.CreateParams(var Params: TCreateParams);
// no taskbar icon for the app
begin
  inherited;
  Params.ExStyle    := Params.ExStyle or (WS_EX_APPWINDOW);
  Params.WndParent  := self.Handle; // normally application.handle
end;

procedure TTimelineForm.pnlCursorMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  FDragging := TRUE;
end;

procedure TTimelineForm.pnlCursorMouseEnter(Sender: TObject);
begin
  screen.cursor := crSizeWE;
end;

procedure TTimelineForm.pnlCursorMouseLeave(Sender: TObject);
begin
  screen.cursor := crDefault;
end;

procedure TTimelineForm.pnlCursorMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
begin
  if FDragging then cursorPos := cursorPos + (X - pnlCursor.Width div 2);
  if FDragging then PB.setNewPosition(cursorPos);
end;

procedure TTimelineForm.pnlCursorMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  FDragging := FALSE;
  PB.setNewPosition(cursorPos);
end;

procedure TTimelineForm.setCursorPos(const Value: integer);
begin
  pnlCursor.left := value;
end;

procedure TTimelineForm.FormCreate(Sender: TObject);
begin
  pnlCursor.height := SELF.height;
  pnlCursor.top    := 0;
  pnlCursor.left   := -1;
end;

procedure TTimelineForm.FormKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  case key = ord('C') of TRUE: begin TL.cutSegment(TL.segmentAtCursor, cursorPos); TL.drawSegments; end;end;
  case key = ord('P') of TRUE: TL.processSegments; end;
  case key = ord('R') of TRUE: begin TL.restoreSegment(TL.selSeg);                 TL.drawSegments; end;end;
  case key = ord('X') of TRUE: begin TL.delSegment(TL.selSeg);                     TL.drawSegments; end;end;
  // I set in point - only if initial segment
  // O set out point - only if initial segment
  // M merge with next segment
  // N merge with prev segment
  case TL.keyHandled(key) of TRUE: key := 0; end;
  case TL.segCount > 0 of TRUE: TL.saveSegments; end;
end;

procedure TTimelineForm.FormResize(Sender: TObject);
begin
  lblPosition.left := (SELF.width div 2) - (lblPosition.width div 2);
  lblPosition.top  := (SELF.height div 2) - (lblPosition.height div 2);
  TL.drawSegments;
end;

function TTimelineForm.getCursorPos: integer;
begin
  result := pnlCursor.left;
end;

{ TTimeline }

function TTimeline.clearFocus: boolean;
begin
  for var vSegment in FSegments do vSegment.selected := FALSE;
  FSelSeg := NIL;
end;

constructor TTimeline.create;
begin
  inherited;
  FSegments       := TList<TSegment>.create;
  FMediaFilePath  := PL.currentItem;
end;

function TTimeline.cutSegment(const aSegment: TSegment; const aCursorPos: integer): boolean;
var
  ix: integer;
  newSegment: TSegment;
begin
  case aSegment = NIL of TRUE: EXIT; end;

//  var newStartSS := trunc((aCursorPos / aSegment.width) * aSegment.duration);
  var newStartSS := MP.position;

  newSegment := TSegment.create(newStartSS, aSegment.EndSS);
  aSegment.EndSS := newStartSS - 1;

  ix := FSegments.IndexOf(aSegment);
  case ix < FSegments.count - 1 of  TRUE: FSegments.insert(ix + 1, newSegment);
                                   FALSE: FSegments.add(newSegment); end;
end;

function TTimeline.delSegment(const aSegment: TSegment): boolean;
begin
  case aSegment = NIL of TRUE: EXIT; end;
  aSegment.deleted    := TRUE;
  case aSegment.color  = NEARLY_BLACK of FALSE: aSegment.oldColor := aSegment.color; end; // in case user tries to delete an already-deleted segment
  aSegment.color      := NEARLY_BLACK;
end;

destructor TTimeline.destroy;
begin
  freeSegments;
  FSegments.free;
  inherited;
end;

function TTimeline.drawSegments: boolean;
begin
  var n := 1;
  for var vSegment in FSegments do begin
    vSegment.top     := 0;
    vSegment.height  := timelineForm.height;
    vSegment.left    := trunc((vSegment.startSS / FMax) * timelineForm.width);
    vSegment.width   := trunc((vSegment.duration / FMax) * timelineForm.width);
    vSegment.caption := '';
    vSegment.segID   := intToStr(n);
    vSegment.setSegDetails;
    vSegment.StyleElements := [];
    VSegment.trashCan.visible := vSegment.deleted;
    case vSegment.deleted of TRUE: begin
                                      vSegment.trashCan.left := (vSegment.width  div 2) - (vSegment.trashCan.width  div 2);
                                      vSegment.trashCan.top  := (vSegment.height div 2) - (vSegment.trashCan.height div 2); end;end;
    vSegment.parent := timelineForm;
    SetWindowPos(vSegment.handle, HWND_BOTTOM, 0, 0, 0, 0, SWP_NOMOVE or SWP_NOSIZE);
    inc(n);
  end;
  timelineForm.pnlCursor.bringToFront;
end;

function TTimeline.freeSegments: boolean;
begin
  FSegments.Clear;
end;

function TTimeline.getMax: integer;
begin
  result := FMax;
end;

function TTimeline.getPosition: integer;
begin
  result := FPosition;
end;

function TTimeline.getSegCount: integer;
begin
  result := FSegments.count;
end;

function TTimeline.initialSegment: boolean;
begin
  freeSegments;
  FSegments.add(TSegment.create(0, FMax));
  drawSegments;
end;

function TTimeline.keyHandled(key: WORD): boolean;
begin
  result := key in [ord('C'), ord('P'), ord('R'), ord('X')];
end;

function TTimeline.loadSegments: boolean;
var
  vSL: TStringList;
  vStartSS: integer;
  vEndSS: integer;
  vDeleted: boolean;
  vSegment: TSegment;
  posDot: integer;
  posComma: integer;
begin
  freeSegments;
  vSL := TStringList.create;
  try
    vSL.loadFromFile(changeFileExt(FMediaFilePath, '.mmp'));
    for var i := 0 to vSL.count - 1 do begin
      posDot := pos('.', vSL[i]);
      vStartSS := strToInt(copy(vSL[i], 1, posDot - 1));
      posComma := pos(',', vSL[i]);
      vEndSS   := strToInt(copy(vSL[i], posDot + 1, posComma - posDot - 1));
      vDeleted := copy(vSL[i], posComma + 1, 1) = '1';
      FSegments.add(TSegment.create(vStartSS, vEndss, vDeleted));
    end;
    vSL.saveToFile(changeFileExt(FMediaFilePath, '.mmp'));
  finally
    vSL.free;
  end;
  drawSegments;
end;

function TTimeline.log(aLogEntry: string): boolean;
begin
  var vLogFile := changeFileExt(FMediaFilePath, '.log');
  var vLog := TStringList.create;
  try
    case fileExists(vLogFile) of TRUE: vLog.loadFromFile(vLogFile); end;
    vLog.add(aLogEntry);
    vLog.saveToFile(vLogFile);
  finally
    vLog.free;
  end;
end;

function TTimeline.processSegments: boolean;
var cmdLine: string;
//  testCmd := '-f concat -safe 0 -i "B:\MoviesToGo\concat.txt" -map "0:0" "-c:0" copy "-disposition:0" default -map "0:1" "-c:1" copy "-disposition:1" default'
//           + ' -map "0:2" "-c:2" copy -movflags "+faststart" -default_mode infer_no_subs -ignore_unknown -f matroska -y "B:\MoviesToGo\Kingsman The Secret Service (2014) [concat].mkv"';

//  var testCmd := '-hide_banner -ss 0 -i "B:\MoviesToGo\Kingsman The Secret Service (2014).mkv" -to 7724'
//               + ' -map 0:0? -c:0 copy -map 0:1? -c:1 copy -map 0:2? -c:2 copy -avoid_negative_ts make_zero -map_metadata 0 -movflags +faststart -default_mode infer_no_subs -ignore_unknown -y "B:\MoviesToGo\Kingsman The Secret Service (2014)-seg03.mkv"';
const
  STD_SEG_PARAMS = ' -avoid_negative_ts make_zero -map 0:0? -c:0 copy -map 0:1? -c:1 copy -map 0:2? -c:2 copy -map 0:3? -c:3 copy -avoid_negative_ts make_zero -map_metadata 0 -movflags +faststart -default_mode infer_no_subs -ignore_unknown';

begin
  var vSL := TStringList.create;
  try
    vSL.saveToFile(changeFileExt(FMediaFilePath, '.seg'));
    var n := 1;
    for var vSegment in FSegments do begin
      case vSegment.deleted of TRUE: CONTINUE; end;

      cmdLine := '-hide_banner';
      cmdLine := cmdLine + ' -ss "' + intToStr(vSegment.startSS) + '"';
      cmdLine := cmdLine + ' -i "' + FMediaFilePath + '"';
      cmdLine := cmdLine + ' -t "'  + intToStr(vSegment.duration) + '"';
      cmdLine := cmdLine + STD_SEG_PARAMS;
      var segFile := extractFilePath(FMediaFilePath) + CU.getFileNameWithoutExtension(FMediaFilePath) + format(' seg%.2d', [n]) + extractFileExt(FMediaFilePath);
      cmdLine := cmdLine + ' -y "' + segFile + '"';
      log(cmdLine);

      case execAndWait(cmdLine) of TRUE: vSL.add('file ''' + stringReplace(segFile, '\', '\\', [rfReplaceAll]) + ''''); end;
      inc(n);
    end;
    vSL.saveToFile(changeFileExt(FMediaFilePath, '.seg'));
  finally
    vSL.free;
  end;

  cmdLine := '-f concat -safe 0 -i "' + changeFileExt(FMediaFilePath, '.seg') + '"';
  cmdLine := cmdLine + ' -map 0:0 -c:0 copy -disposition:0 default -map 0:1 -c:1 copy -disposition:1 default -map 0:2 -c:2 copy -disposition:2 default';
  cmdLine := cmdLine + ' -movflags "+faststart" -default_mode infer_no_subs -ignore_unknown';
  cmdLine := cmdLine + ' -y "' + extractFilePath(FMediaFilePath) + CU.getFileNameWithoutExtension(FMediaFilePath) + ' [edited]' + extractFileExt(FMediaFilePath) + '"';
  log(cmdLine);

  result := execAndWait(cmdLine);
end;

function TTimeline.restoreSegment(const aSegment: TSegment): boolean;
begin
  case aSegment = NIL of TRUE: EXIT; end;
  aSegment.deleted := FALSE;
  case aSegment.oldColor = NEARLY_BLACK of FALSE: aSegment.color := aSegment.oldColor; end;
end;

function TTimeline.saveSegments: boolean;
begin
  var vSL := TStringList.create;
  try
    for var vSegment in FSegments do
      vSL.add(format('%d.%d,%d', [vSegment.startSS, vSegment.endSS, integer(vSegment.deleted)]));

    vSL.saveToFile(changeFileExt(FMediaFilePath, '.mmp'));
  finally
    vSL.free;
  end;
end;

function TTimeline.segmentAtCursor: TSegment;
begin
  result := NIL;
  for var vSegment in FSegments do
    case (vSegment.left <= timelineForm.cursorPos) and (vSegment.left + vSegment.width >= timelineForm.cursorPos) of TRUE: result := vSegment; end;
end;

procedure TTimeline.setMax(const Value: integer);
begin
  FMax := value;
  case fileExists(changeFileExt(FMediaFilePath, '.mmp')) of  TRUE: loadSegments;
                                                            FALSE: initialSegment; end;
end;

procedure TTimeline.setPosition(const Value: integer);
begin
  FPosition := value;
  timelineForm.pnlCursor.left := trunc((FPosition / FMax) * timelineForm.width) - timelineForm.pnlCursor.width;
  timelineForm.lblPosition.caption  := MP.formattedTime;
end;

{ TSegment }

procedure CopyPNGImage(SourceImage, DestImage: TImage);
begin
  // Check if the source image has a picture to copy
  if Assigned(SourceImage.Picture) and Assigned(SourceImage.Picture.Graphic) then
  begin
    // Clear the destination image
    DestImage.Picture := nil;

    // Assign the graphic content from the source to the destination
    DestImage.Picture.Assign(SourceImage.Picture.Graphic);
  end;
end;

procedure TSegment.doClick(Sender: TObject);
begin
  TL.clearFocus;
  TL.selSeg  := SELF;
  selected   := TRUE;
end;

constructor TSegment.create(const aStartSS: integer; const aEndSS: integer; const aDeleted: boolean = FALSE);
begin
  inherited create(timelineForm);
  height            := timelineForm.height;
  font.color        := clSilver;
  font.size         := 10;
  font.style        := [fsBold];
  alignment         := taLeftJustify;
  onClick           := doClick;
  doubleBuffered    := TRUE;

  startSS           := aStartSS;
  endSS             := aEndSS;
  borderStyle       := bsNone;
  bevelOuter        := bvNone;
  color             := generateRandomEvenDarkerSoftColor;
  oldColor          := color;

  FSegID            := TLabel.create(SELF);
  FSegID.parent     := SELF;
  FSegID.top        := 0;
  FSegID.left       := 4;
  FSegID.styleElements := [];

  FSegDetails := TLabel.create(SELF);
  FSegDetails.parent     := SELF;
  FSegDetails.top        := 38;
  FSegDetails.left       := 4;
  FSegDetails.styleElements := [];

  FTrashCan := TImage.create(SELF);
  FTrashCan.parent := SELF;
  FTrashCan.stretch := TRUE;
  FTrashCan.center  := TRUE;
  FTrashCan.height  := 31;
  FTrashCan.width   := 41;
  FTrashCan.visible := FALSE;
  FTrashCan.onClick := doClick;
  CopyPNGImage(timelineForm.imgTrashCan, FTrashCan);

  case aDeleted of TRUE: TL.delSegment(SELF); end;
end;

function TSegment.getDuration: integer;
begin
  result := FEndSS - FStartSS;
end;

function TSegment.getSegID: string;
begin
  result := FSegID.caption;
end;

procedure TSegment.paint;
begin
  var rect := getClientRect;
  canvas.brush.color := color;
  canvas.fillRect(rect);

  case selected of  TRUE: Frame3D(canvas, rect, clTeal, clTeal, 1);
                   FALSE: Frame3D(canvas, rect, color, color, 1); end;
end;

procedure TSegment.setSegDetails;
begin
  FSegDetails.caption := format('%ds - %ds', [startSS, endSS]);
end;

procedure TSegment.setSegID(const Value: string);
begin
  FSegID.caption := value;
end;

procedure TSegment.setSelected(const Value: boolean);
begin
  FSelected := Value;
  invalidate;
end;

initialization
  timelineForm := NIL;
  gTL          := NIL;

finalization
  case timelineForm <> NIL of TRUE: begin timelineForm.close; timelineForm.free; timelineForm := NIL; end;end;
  case gTL          <> NIL of TRUE: begin gTL.free; gTL := NIL; end;end;

end.
{   MMP: Minimalist Media Player
    Copyright (C) 2021-2024 Baz Cuda
    https://github.com/BazzaCuda/MinimalistMediaPlayerX

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
unit TUICtrlsClass;

interface

uses
  winApi.shellAPI, winApi.windows,
  system.classes,
  vcl.comCtrls, vcl.controls, vcl.extCtrls, vcl.forms, vcl.graphics,
  mmpConsts;

type
  TUI = class(TObject)
  strict private
    FMainForm:        TForm;
    FFormattedTime:   string;
    FForcedResize:    boolean;
    FInitialized:     boolean;
    FPrevImageHeight: integer;
    FPrevVideoHeight: integer;
    FSettingSize:     boolean;
    FTweaking:        boolean;
    FUserJ:           boolean;
    FVideoPanel:      TPanel;
  private
    function addMenuItems(const aForm: TForm): boolean;
    function createVideoPanel(const aForm: TForm): boolean;
    function setCustomTitleBar(const aForm: TForm): boolean;
    function setGlassFrame(const aForm: TForm): boolean;
    function setWindowStyle(const aForm: TForm): boolean;
    function getHeight: integer;
    function getWidth: integer;
    function getXY: TPoint;
    procedure formKeyDn(sender: TObject; var key: WORD; shift: TShiftState);
    procedure formKeyUp(sender: TObject; var key: WORD; shift: TShiftState);
    procedure onMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure onMPBeforeNew(sender: TObject);
    procedure onMPPlayNew(sender: TObject);
    procedure onMPPlayNext(sender: TObject);
    procedure onMPPosition(const aMax: integer; const aPosition: integer);
  public
    procedure formResize(sender: TObject);
    function adjustAspectRatio: boolean;
    function arrangeAll: boolean;
    function autoCentreWindow(const aWnd: HWND): boolean;
    function centreCursor: boolean;
    function centreWindow(const aWnd: HWND): boolean;
    function checkScreenLimits(const aWnd: HWND; const aWidth: integer; const aHeight: integer): boolean;
    function darker: boolean;
    function doEscapeKey: boolean;
    function greaterWindow(const aWnd: HWND; aShiftState: TShiftState): boolean;
    function handle: HWND;
    function initUI(const aForm: TForm): boolean;
    function keepFile(const aFilePath: string): boolean;
    function maximize: boolean;
    function minimizeWindow: boolean;
    function moveHelpWindow(const create: boolean = TRUE): boolean;
    function movePlaylistWindow(const createNew: boolean = TRUE): boolean;
    function moveTimelineWindow(const createNew: boolean = TRUE): boolean;
    function posWinXY(const aHWND: HWND; const x: integer; const y: integer): boolean;
    function renameFile(const aFilePath: string): boolean;
    function resetColor: boolean;
    function resize(const aWnd: HWND; const pt: TPoint; const X: int64; const Y: int64): boolean;
    function setWindowSize(const aStartingHeight: integer; const aShiftState: TShiftState): boolean;
    function showThumbnails(const aHostType: THostType = htThumbsHost): boolean;
    function showWindow: boolean;
    function showXY: boolean;
    function shutTimeline: boolean;
    function smallerWindow(const aWnd: HWND): boolean;
    function toggleBlackout: boolean;
    function toggleCaptions: boolean;
    function toggleTimeline: boolean;
    function toggleHelpWindow: boolean;
    function toggleMaximized: boolean;
    function togglePlaylist: boolean;
    property height: integer read getHeight;
    property initialized: boolean read FInitialized write FInitialized;
    property XY: TPoint read getXY;
    property videoPanel: TPanel read FVideoPanel;
    property width: integer read getWidth;
  end;

implementation

uses
  winApi.messages,
  system.math, system.sysUtils,
  vcl.dialogs,
  mmpDesktopUtils, mmpDialogs, mmpFileUtils, mmpKeyboard, mmpMathUtils, mmpPlaylistUtils, mmpMPVFormatting, mmpShellUtils, mmpSingletons, mmpSysCommands, mmpUtils, mmpWindowCtrls,
  formHelp, formPlaylist, formThumbs, formTimeline,
  _debugWindow;

{ TUI }

function TUI.addMenuItems(const aForm: TForm): boolean;
begin
  var vSysMenu := getSystemMenu(aForm.handle, FALSE);
  AppendMenu(vSysMenu, MF_SEPARATOR, 0, '');
  AppendMenu(vSysMenu, MF_STRING, MENU_ABOUT_ID, '&About Minimalist Media Player�');
  AppendMenu(vSysMenu, MF_STRING, MENU_HELP_ID, 'Show &Keyboard functions');
end;

function TUI.adjustAspectRatio: boolean;
var
  vWidth:  integer;
  vHeight: integer;

  function adjustWidthForAspectRatio: boolean;
  begin
    vWidth := round(vHeight / MP.videoHeight * MP.videoWidth);
  end;

begin
  case (MP.videoWidth <= 0) OR (MP.videoHeight <= 0) of TRUE: EXIT; end;
  FUserJ := TRUE;

  mmpWndWidthHeight(SELF.handle, vWidth, vHeight);

  vHeight := FVideoPanel.height;

  adjustWidthForAspectRatio;

  vWidth  := vWidth  + 2;   // allow for the mysterious 1-pixel border that Windows insists on drawing around a borderless window
  vHeight := vHeight + 2;

  SetWindowPos(SELF.Handle, HWND_TOP, (mmpScreenWidth - vWidth) div 2, (mmpScreenHeight - vHeight) div 2, vWidth, vHeight, SWP_NOMOVE); // resize window
  mmpProcessMessages;

  case GV.autoCentre of TRUE: autoCentreWindow(GV.appWnd); end;
  showXY;
end;

function TUI.arrangeAll: boolean;
var
  vCount: integer;
  vWidth, vHeight: integer;
  vScreenWidth, vScreenHeight: integer;
  vZero: integer;
  vHMiddle, vVMiddle: integer;
begin
  vCount     := SA.count;

  GV.autoCentre := vCount = 1;
  case GV.autoCentre of FALSE:  begin
                                  mmpPostToAll(WIN_AUTOCENTRE_OFF, TRUE);
                                  mmpPostToAll(WIN_MAX_SIZE_OFF, TRUE); end;end;

  case vCount of
    1:       mmpPostToAllEx(WIN_RESIZE, point(mmpScreenWidth, 0), TRUE);
    2:       mmpPostToAllEx(WIN_RESIZE, point(mmpScreenWidth div 2, 0), TRUE);
    3, 4:    mmpPostToAllEx(WIN_RESIZE, point(0, mmpScreenHeight div 2), TRUE);
    else     mmpPostToAllEx(WIN_RESIZE, point(mmpScreenWidth div vCount, 0), TRUE);
  end;

  mmpProcessMessages; // make sure this window has resized before continuing
  mmpPostToAll(WM_PROCESS_MESSAGES, TRUE);

  mmpWndWidthHeight(UI.handle, vWidth, vHeight);
  vScreenWidth  := mmpScreenWidth;
  vScreenHeight := mmpScreenHeight;
  vHMiddle      := vScreenWidth div 2;
  vVMiddle      := vScreenHeight div 2;
  vZero         := vHMiddle - vWidth;

  vCount := SA.count;
  var vHWND := 0;

  case vCount = 2 of TRUE: begin
                             posWinXY(SA.HWNDs[1], vZero,    (vScreenHeight - vHeight) div 2);
                             posWinXY(SA.HWNDs[2], vHMiddle, (vScreenHeight - vHeight) div 2);
                             case mmpOffScreen(SA.HWNDs[1]) of TRUE: posWinXY(SA.HWNDs[1], vZero, 0); end;
                             case mmpOffScreen(SA.HWNDs[2]) of TRUE: posWinXY(SA.HWNDs[2], vHMiddle, 0); end;
                             vHWND := SA.HWNDs[1];
                           end;end;

  case vCount in [3, 4] of TRUE: begin
                             posWinXY(SA.HWNDs[1], vZero,  0 + 40);
                             posWinXY(SA.HWNDs[2], vHMiddle, 0 + 40); end;end;

  case vCount = 3 of TRUE: posWinXY(SA.HWNDs[3], vHMiddle - (vWidth div 2), vHeight + 40); end;

  case vCount = 4 of TRUE: begin
                              posWinXY(SA.HWNDs[3], vZero,  vHeight + 40);
                              posWinXY(SA.HWNDs[4], vHMiddle, vHeight + 40); end;end;

  case vCount > 4 of TRUE: for var i := 1 to vCount do posWinXY(SA.HWNDs[i], ((mmpScreenWidth div vCount) * (i - 1)), 100); end;

  mmpPostToAll(WM_PROCESS_MESSAGES, TRUE);

  case vHWND <> 0 of TRUE: begin mmpDelay(100); posWinXY(vHWND, mmpScreenCentre - UI.width, UI.XY.Y); end;end; // hack for tall, narrow, TikTok-type windows
end;

function TUI.autoCentreWindow(const aWnd: HWND): boolean;
begin
  case GV.autoCentre of FALSE: EXIT; end;
  centreWindow(aWnd);
end;

function TUI.centreCursor: boolean;
begin
//  case GV.autoCentre AND (MP.MediaType <> mtImage) and NOT GV.showingTimeline of TRUE: postMessage(GV.appWND, WM_CENTRE_CURSOR, 0, 0); end;
end;

function TUI.centreWindow(const aWnd: HWND): boolean;
var
  vR: TRect;
  vHPos: integer;
  vVPos: integer;

  function alreadyCentred: boolean;
  begin
    vHPos := (mmpScreenWidth  - vR.width) div 2;
    vVPos := (mmpScreenHeight - vR.height) div 2;
    result := (vR.left = vHPos) and (vR.top = vVPos);
  end;

begin
  getWindowRect(aWnd, vR);
  GV.autoCentre := TRUE; // user pressing [H] re-instates autoCentre

  case alreadyCentred of TRUE: EXIT; end;

  case mmpWithinScreenLimits(vR.width, vR.height) of FALSE: postMessage(GV.appWnd, WM_CHECK_SCREEN_LIMITS, 0, 0); end;

  case (vHPos > 0) and (vVPos > 0) of TRUE: SetWindowPos(aWnd, HWND_TOP, vHPos, vVPos, 0, 0, SWP_NOSIZE); end;

  mmpProcessMessages;
  moveHelpWindow(FALSE);
  movePlaylistWindow(FALSE);
  moveTimelineWindow(FALSE);
end;

function TUI.checkScreenLimits(const aWnd: HWND; const aWidth: integer; const aHeight: integer): boolean;
var
  vR:       TRect;
  vWidth:   integer;
  vHeight:  integer;
begin
  case GV.closeApp of TRUE: EXIT; end;

  getWindowRect(aWnd, vR);
  vWidth  := vR.width;
  vHeight := vR.height;

  case (vWidth > aWidth) or (vHeight > aHeight) of  TRUE: postMessage(GV.appWnd, WM_SMALLER_WINDOW, 0, 0);
                                                   FALSE: postMessage(GV.appWnd, WM_USER_CENTRE_WINDOW, 0, 0); end;

  mmpProcessMessages;
end;

function TUI.darker: boolean;
begin
  CF['caption']     := CF.toHex(MC.darker);
  CF['timeCaption'] := CF.toHex(ST.darker);
  CF['progressBar'] := CF.toHex(PB.darker);
end;

function TUI.createVideoPanel(const aForm: TForm): boolean;
begin
  FVideoPanel             := TPanel.create(aForm);
  FVideoPanel.parent      := aForm;
  FVideoPanel.align       := alClient;
  FVideoPanel.color       := clBlack;
  FVideoPanel.BevelOuter  := bvNone;
  FVideoPanel.OnMouseMove := onMouseMove;
end;

function TUI.doEscapeKey: boolean;
begin
  case FMainForm.WindowState = wsMaximized of  TRUE: toggleMaximized;
                                              FALSE: begin MP.ceaseOps; mmpSendSysCommandClose; end;end;
end;

procedure TUI.formResize(sender: TObject);
begin
  case GV.closeApp  of TRUE:  EXIT; end;
  case FInitialized of FALSE: EXIT; end;
  case PL.hasItems  of FALSE: EXIT; end;
  case ST.initialized and PB.initialized   of FALSE: EXIT; end;
  case FMainForm.WindowState = wsMaximized of TRUE:  EXIT; end;
  case FTweaking of TRUE: EXIT; end;

  mmpDelay(100);

  case FForcedResize of TRUE: begin FForcedResize := FALSE; EXIT; end;end; // in response to Ctrl-[9], Arrange All

  case FUserJ of   TRUE: FUserJ := FALSE;
                  FALSE: setWindowSize(UI.height, []); end;

  ST.formResize(UI.width);
  PB.formResize;

  moveHelpWindow(FALSE);
  movePlaylistWindow(FALSE);
  moveTimelineWindow(FALSE);
  case MP.mediaType = mtImage of TRUE: showXY; end;
end;

procedure TUI.formKeyDn(sender: TObject; var key: WORD; shift: TShiftState);
// keys that don't generate a standard WM_KEYUP message
begin
  GV.altKeyDown := ssAlt in shift;
  case GV.altKeyDown of TRUE: mmpPostToAll(WIN_TABALT, KBNumLock); end;
end;

procedure TUI.formKeyUp(sender: TObject; var key: WORD; shift: TShiftState);
// keys that don't generate a standard WM_KEYUP message
begin
  GV.altKeyDown := NOT (key = VK_MENU);
  case key in [VK_F10] of TRUE: begin
                               postMessage(GV.appWnd, WM_KEY_UP, key, 0);
                               mmpProcessMessages; end;end;
end;

function TUI.getHeight: integer;
var vWidth: integer; vHeight: integer;
begin
  mmpWndWidthHeight(UI.handle, vWidth, vHeight);
  result := vHeight;
end;

function TUI.getWidth: integer;
var vWidth: integer; vHeight: integer;
begin
  mmpWndWidthHeight(UI.handle, vWidth, vHeight);
  result := vWidth;
end;

function TUI.getXY: TPoint;
var vR: TRect;
begin
  getWindowRect(UI.handle, vR);
  result := vR.Location;
end;

function TUI.greaterWindow(const aWnd: HWND; aShiftState: TShiftState): boolean;
const
  dx = 50;
  dy = 30;
var
  vR: TRect;
begin
  case GV.greatering and GV.showingHelp of TRUE: EXIT; end;
  case FSettingSize and (GV.showingPlaylist or GV.showingTimeline) of TRUE: EXIT; end; // limit keyboard keystroke repetitions for held down Ctrl-[G]
  GV.greatering := TRUE;

  getWindowRect(aWnd, vR);

  GV.maxSize := FALSE; // pressing [M] reinstates maxSize

  case ssCtrl in aShiftState of  TRUE: setWindowSize(vR.height - dy, aShiftState);
                                FALSE: setWindowSize(vR.height + dy, aShiftState); end;

  GV.greatering := FALSE;
end;

function TUI.handle: HWND;
begin
  result := FMainForm.handle;
end;

function TUI.initUI(const aForm: TForm): boolean;
begin
  FMainForm           := aForm;
  GV.mainForm         := aForm;
  aForm.OnKeyDown     := formKeyDn;
  aForm.OnKeyUp       := formKeyUp;
  aForm.OnResize      := formResize;
  aForm.position      := poScreenCenter;
  aForm.borderIcons   := [biSystemMenu];
  aForm.styleElements := [];
  setGlassFrame(aForm);
  setCustomTitleBar(aForm);
  setWindowStyle(aForm);
  DragAcceptFiles(aForm.handle, TRUE);
  addMenuItems(aForm);
  aForm.color         := clBlack; // background color of the window's client area, so zooming-out doesn't show the design-time color
  createVideoPanel(aForm);
  GV.autoCentre       := TRUE;
  GV.maxSize          := TRUE;
  aForm.width         := trunc((mmpScreenHeight - 100) * 1.5);
  aForm.height        := mmpScreenHeight - 100;
  MP.onBeforeNew      := onMPBeforeNew;
  MP.onPlayNew        := onMPPlayNew;
  MP.onPlayNext       := onMPPlayNext;
  MP.onPosition       := onMPPosition;
end;

function TUI.keepFile(const aFilePath: string): boolean;
var
  vNewName: string;
  vWasPlaying: boolean;
begin
  case PL.hasItems of FALSE: EXIT; end;

  vWasPlaying := MP.playing;
  case vWasPlaying of TRUE: MP.pause; end;

  vNewName := mmpRenameFile(aFilePath, '_' + mmpFileNameWithoutExtension(aFilePath));
  case vNewName <> aFilePath of TRUE: begin
                                        PL.replaceCurrentItem(vNewName);
                                        ST.opInfo := 'Kept'; end;end;
  MC.caption := PL.formattedItem;
  case vWasPlaying  of TRUE: MP.resume; end;
end;

function TUI.maximize: boolean;
begin
  FUserJ        := FALSE;
  GV.autoCentre := TRUE;
  GV.maxSize    := TRUE;
  setWindowSize(-1, []);
  centreCursor;
end;

function TUI.minimizeWindow: boolean;

begin
   postMessage(UI.handle, WM_SYSCOMMAND, SC_MINIMIZE, 0);
end;

function TUI.moveHelpWindow(const create: boolean = TRUE): boolean;
begin
  var vPt := FVideoPanel.ClientToScreen(point(FVideoPanel.left + FVideoPanel.width + 1, FVideoPanel.top - 2)); // screen position of the top right corner of the application window, roughly.
  showHelp(SELF.handle, vPt, FVideoPanel.height, htHelp, create);
end;

function TUI.movePlaylistWindow(const createNew: boolean = TRUE): boolean;
begin
  var vPt := FVideoPanel.ClientToScreen(point(FVideoPanel.left + FVideoPanel.width, FVideoPanel.top - 2)); // screen position of the top right corner of the application window, roughly.
  showPlaylist(PL, vPt, videoPanel.height, createNew);
end;

function TUI.moveTimelineWindow(const createNew: boolean = TRUE): boolean;
begin
  var vPt := FVideoPanel.ClientToScreen(point(FVideoPanel.left, FVideoPanel.height)); // screen position of the bottom left corner of the application window, roughly.
  showTimeline(vPt, FVideoPanel.width, createNew);
end;

procedure TUI.onMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
// doesn't work in TAppEventsClass. Spurious WM_MOUSEMOVE events are generated even with no mouse connected!
begin
  case screen <> NIL of TRUE: screen.cursor := crDefault; end;
end;

procedure TUI.onMPBeforeNew(sender: TObject);
begin
  case GV.showingTimeline of TRUE: TL.clear; end;
end;

procedure TUI.onMPPlayNew(sender: TObject);
begin
  case GV.showingTimeline of TRUE: TL.initTimeline(PL.currentItem, MP.duration); end;
end;

procedure TUI.onMPPlayNext(sender: TObject);
begin
  movePlaylistWindow(FALSE);
end;

procedure TUI.onMPPosition(const aMax: integer; const aPosition: integer);
begin
  case GV.showingTimeline of TRUE: begin TL.max := aMax; TL.position := aPosition; end;end;
end;

function TUI.posWinXY(const aHWND: HWND; const x: integer; const y: integer): boolean;
begin
  SetWindowPos(aHWND, HWND_TOP, x, y, 0, 0, SWP_NOSIZE);
end;

function TUI.renameFile(const aFilePath: string): boolean;
var
  vNewName: string;
  vWasPlaying: boolean;
  vWasPlaylist: boolean;
begin
  case PL.hasItems of FALSE: EXIT; end;

  vWasPlaying := MP.playing;
  case vWasPlaying of TRUE: MP.pause; end;

  vWasPlaylist := GV.showingPlaylist;
  case vWasPlaylist of TRUE: shutPlaylist; end;

  vNewName := mmpRenameFile(aFilePath);
  case vNewName = aFilePath of FALSE: PL.replaceCurrentItem(vNewName); end;
  MC.caption := PL.formattedItem;

  case vWasPlaying  of TRUE: MP.resume; end;
  case vWasPlaylist of TRUE: movePlaylistWindow; end;
end;

function TUI.resize(const aWnd: HWND; const pt: TPoint; const X: int64; const Y: int64): boolean;
// X and Y are the video dimensions
// pt.x is the designated width, or...
// py.y is the designated height
var
  vRatio: double;
  vWidth, vHeight: integer;

  function adjustWidthForAspectRatio: boolean;
  begin
    vWidth := trunc(vHeight / Y * X);
  end;

  function adjustHeightForAspectRatio: boolean;
  begin
    vHeight := trunc(Y * (vWidth / X));
  end;

  function withinScreenLimits: boolean;
  begin
    result := (vWidth <= mmpScreenWidth) and (vHeight <= mmpScreenHeight);
  end;

begin
  case (X <= 0) OR (Y <= 0) of TRUE: EXIT; end;

  vWidth  := pt.x;
  vHeight := pt.y;

  case pt.x <> 0 of TRUE: repeat vWidth  := vWidth  - 50; adjustHeightForAspectRatio; until withinScreenLimits; end;

  case pt.y <> 0 of TRUE: repeat vHeight := vHeight - 50; adjustWidthForAspectRatio;  until withinScreenLimits; end;

  FForcedResize := TRUE;
  sendMessage(aWnd, WM_SYSCOMMAND, SC_RESTORE, 0); // in case it was minimized
  SetWindowPos(aWnd, HWND_TOPMOST, 0, 0, vWidth, vHeight, SWP_NOMOVE);      // Both SWPs achieve HWND_TOP as HWND_TOP itself doesn't work.
  SetWindowPos(aWnd, HWND_NOTOPMOST, 0, 0, 0, 0, SWP_NOMOVE or SWP_NOSIZE); // resize the window. Triggers adjustAspectRatio
end;

function TUI.setCustomTitleBar(const aForm: TForm): boolean;
begin
  aForm.customTitleBar.enabled        := TRUE;
  aForm.customTitleBar.showCaption    := FALSE;
  aForm.customTitleBar.showIcon       := FALSE;
  aForm.customTitleBar.systemButtons  := FALSE;
  aForm.customTitleBar.systemColors   := FALSE;
  aForm.customTitleBar.systemHeight   := FALSE;
  aForm.customTitleBar.height         := 1; // systemHeight=FALSE must be set before this
end;

function TUI.setGlassFrame(const aForm: TForm): boolean;
begin
  aForm.glassFrame.enabled  := TRUE;
  aForm.glassFrame.top      := 1;
end;

function TUI.setWindowSize(const aStartingHeight: integer; const aShiftState: TShiftState): boolean;
var
  vWidth:           integer;
  vHeight:          integer;
  dy:               integer;
  vStartingHeight:  integer;

  function adjustWidthForAspectRatio: boolean;
  begin
    case (MP.videoWidth = 0) or (MP.videoHeight = 0) of TRUE: EXIT; end;
    vWidth := trunc(vHeight / MP.videoHeight * MP.videoWidth);
  end;

  function withinScreenLimits: boolean;
  begin
    result := (vWidth <= mmpScreenWidth) and (vHeight <= mmpScreenHeight);
  end;

begin
  FSettingSize := TRUE;
  case MP.mediaType of  mtAudio:  begin case MI.hasCoverArt of  TRUE: vWidth  := 600;
                                                               FALSE: vWidth  := 600; end;
                                        case MI.hasCoverArt of  TRUE: vHeight := 400;
                                                               FALSE: vHeight := UI_DEFAULT_AUDIO_HEIGHT; end;
                                        case MI.hasCoverArt of  TRUE: begin while (MP.videoWidth = 0) or (MP.videoHeight = 0) do mmpDelay(100);
                                                                            adjustWidthForAspectRatio; end;end;
                                  end;

                        mtVideo:  begin
                                        vStartingHeight := aStartingHeight;
                                        case GV.maxSize of TRUE: vStartingHeight := -1; end;
                                        case (vStartingHeight <> -1) and (vStartingHeight <= UI_DEFAULT_AUDIO_HEIGHT) of TRUE: vStartingHeight := FPrevVideoHeight; end;
                                        case (vStartingHeight <> -1) and (vStartingHeight <= UI_DEFAULT_AUDIO_HEIGHT) of TRUE: vStartingHeight := -1; end;

                                        case ssCtrl in aShiftState of  TRUE: dy := -30;
                                                                      FALSE: dy := +30; end;

                                        case vStartingHeight = -1 of
                                                                       TRUE: vHeight := mmpScreenHeight - 30;
                                                                      FALSE: vHeight := vStartingHeight; end;

                                        while (MP.videoWidth = 0) or (MP.videoHeight = 0) do mmpDelay(100);

                                        adjustWidthForAspectRatio;

                                        while NOT withinScreenLimits do
                                        begin
                                          dy := -30;
                                          vHeight := vHeight + dy;
                                          adjustWidthForAspectRatio;
                                        end;

                                        FPrevVideoHeight := vHeight;
                                  end;

                        mtImage:  begin
                                        vStartingHeight := aStartingHeight;
                                        case GV.maxSize of TRUE: vStartingHeight := -1; end;
                                        case (vStartingHeight <> -1) and (vStartingHeight <= UI_DEFAULT_AUDIO_HEIGHT) of TRUE: vStartingHeight := FPrevImageHeight; end;
                                        case (vStartingHeight <> -1) and (vStartingHeight <= UI_DEFAULT_AUDIO_HEIGHT) of TRUE: vStartingHeight := -1; end;

                                        case vStartingHeight = -1 of  TRUE: begin
                                                                              vWidth  := trunc((mmpScreenHeight - 100) * 1.5);
                                                                              vHeight := mmpScreenHeight - 100; end;
                                                                     FALSE: begin
                                                                              vWidth  := trunc(vStartingHeight * 1.5);
                                                                              vHeight := vStartingHeight; end;end;

                                        while NOT withinScreenLimits do
                                        begin
                                          vWidth  := vWidth  - 30;
                                          vHeight := vHeight - 30;
                                        end;

                                        FPrevImageHeight := vHeight;
                                  end;
  end;

  case GV.autoCentre of TRUE: SetWindowPos(FMainForm.Handle, HWND_TOP, (mmpScreenWidth - vWidth) div 2, (mmpScreenHeight - vHeight) div 2, 0, 0, SWP_NOSIZE); end; // center window
  mmpProcessMessages;
  SetWindowPos(FMainForm.Handle, HWND_TOP, 0, 0, vWidth, vHeight, SWP_NOMOVE); // resize window
  mmpProcessMessages;
  FSettingSize := FALSE;
end;

function TUI.setWindowStyle(const aForm: TForm): boolean;
begin
  SetWindowLong(aForm.handle, GWL_STYLE, GetWindowLong(aForm.handle, GWL_STYLE) OR WS_CAPTION AND NOT WS_BORDER AND NOT WS_VISIBLE);
end;

function TUI.showThumbnails(const aHostType: THostType = htThumbsHost): boolean;
  function mainFormDimensions: TRect;
  begin
    result.top    := FMainForm.top;
    result.left   := FMainForm.left;
    result.width  := FMainForm.width;
    result.height := FMainForm.height;
  end;
begin
  shutHelp;
  shutPlaylist;
  shutTimeline;
  case MP.imagesPaused of FALSE: MP.pausePlay; end;
  MP.pause;

  case formThumbs.showThumbs(PL.currentItem, mainFormDimensions, aHostType) of mrAll: EXIT; end; // showModal; user pressed Ctrl-[0]

  FMainForm.show;
  setActiveWindow(FMainForm.handle);

  mmpCheckPlaylistItemExists(PL, MP, CF.asBoolean[CONF_NEXT_FOLDER_ON_EMPTY]);
end;

function TUI.showWindow: boolean;
begin
  case GV.closeApp of TRUE: EXIT; end;
  winAPI.windows.showWindow(FMainForm.Handle, SW_SHOW); // solves the "Cannot change Visible in onShow or in onHide" error
  FMainForm.visible := TRUE;                            // still needed in addition to the previous in order to get a mouse cursor!
end;

function TUI.showXY: boolean;
begin
  case MP.mediaType of
    mtImage: ST.opInfo := mmpformatWidthHeight(FVideoPanel.width, FVideoPanel.height);
    // On modern large, wide screens, it's useful to have this displayed both top left and bottom right, depending on how you're sat/slumped :D
    mtVideo: ST.opInfo := PL.formattedItem; end;
end;

function TUI.shutTimeline: boolean;
begin
  formTimeline.shutTimeline;
end;

function TUI.smallerWindow(const aWnd: HWND): boolean;
begin
  greaterWindow(aWnd, [ssCtrl]);
end;

function TUI.toggleBlackout: boolean;
begin
  PB.showProgressBar := NOT PB.showProgressBar;
end;

function TUI.resetColor: boolean;
begin
  CF['caption']     := CF.toHex(MC.resetColor);
  CF['timeCaption'] := CF.toHex(ST.resetColor);
  CF['progressBar'] := CF.toHex(PB.resetColor);
end;

function TUI.toggleCaptions: boolean;
begin
  var vShiftState := mmpShiftState;
  case (ssCtrl in vShiftState) and ST.showTime and (NOT ST.showData) of TRUE: begin MI.getMetaData(ST.dataMemo); ST.showData := TRUE; EXIT; end;end;

  ST.showTime := NOT ST.showTime;

  case (ssCtrl in vShiftState) and ST.showTime of  TRUE: begin MI.getMetaData(ST.dataMemo); ST.showData := TRUE; end;
                                                  FALSE: ST.showData := FALSE; end;
end;

function TUI.toggleTimeline: boolean;
begin
  shutHelp;
  shutPlaylist;

  case mmpIsEditFriendly(PL.currentItem) of FALSE: begin mmpShowOKCancelMsgDlg(PL.currentItem + #13#10#13#10
                                                                             + 'The path/filename contains a single quote and/or an ampersand.'#13#10#13#10
                                                                             + 'This will cause the Export and Join command line operations to fail.'#13#10#13#10
                                                                             + 'Rename the path/filename first.',
                                                                               mtInformation, [MBOK]);
                                                         EXIT; end;end;


  case GV.showingTimeline of  TRUE: shutTimeline;
                             FALSE: moveTimelineWindow; end;

  case GV.showingTimeline of TRUE: begin smallerWindow(handle); TL.initTimeline(PL.currentItem, MP.duration); end;end;

  MP.dontPlayNext := GV.showingTimeline;
  MP.keepOpen     := GV.showingTimeline;
end;

function TUI.toggleHelpWindow: boolean;
begin
  shutPlaylist;
  shutTimeline;

  case GV.showingHelp of  TRUE: shutHelp;
                      FALSE: moveHelpWindow; end;
end;

function TUI.toggleMaximized: boolean;
begin
  case FMainForm.WindowState <> wsMaximized of  TRUE: FMainForm.windowState := wsMaximized;
                                               FALSE: FMainForm.windowState := wsNormal; end;
end;

function TUI.togglePlaylist: boolean;
begin
  shutHelp;
  shutTimeline;

  case showingPlaylist of  TRUE: shutPlaylist;
                          FALSE: movePlaylistWindow; end;
end;

end.

{   Minimalist Media Player
    Copyright (C) 2021-2024 Baz Cuda
    https://github.com/BazzaCuda/MinimalistMediaPlayerX

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307, USA
}
unit formThumbs;

interface

uses
  winApi.messages, winApi.windows,
  system.classes, vcl.graphics, system.sysUtils, system.variants,
  vcl.appEvnts, vcl.controls, vcl.dialogs, vcl.extCtrls, vcl.Forms, Vcl.ComCtrls,
  MPVBasePlayer,
  formProgress,
  mmpConsts, mmpThumbsKeyboard,
  TMPVHostClass, TThumbsClass;

type
  THostType = (htMPVHost, htThumbsHost);

  TThumbsForm = class(TForm)
    FStatusBar: TStatusBar;
    FThumbsHost: TPanel;
    applicationEvents: TApplicationEvents;
    timer: TTimer;
    procedure applicationEventsHint(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure FormShow(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure FStatusBarResize(Sender: TObject);
    procedure timerTimer(Sender: TObject);
    procedure FStatusBarDrawPanel(StatusBar: TStatusBar; Panel: TStatusPanel; const Rect: TRect);
  strict private
    mpv: TMPVBasePlayer;
    FImageDisplayDurationMs:  double;
    FInitialFilePath:         string;
    FLocked:                  boolean;
    FProgressForm:            TProgressForm;
    FKeyHandled:              boolean;
    FMPVHost:                 TMPVHost;
    FShowing:                 boolean;
    FSlideshowDirection:      TSlideshowDirection;
    FThumbs:                  TThumbs;
  private
    procedure onInitMPV(sender: TObject);
    procedure onOpenFile(const aURL: string);
    procedure onStateChange(cSender: TObject; eState: TMPVPlayerState);
    function adjustAspectRatio: boolean;
    function autoCentre: boolean;
    function checkWindowSize(const aCtrlKeyDown: boolean): boolean;
    function deleteCurrentItem: boolean;
    function keepFile(const aFilePath: string): boolean;
    function maximizeWindow: boolean;
    function minimizeWindow: boolean;
    function moveHelpWindow(const aCreateNew: boolean = FALSE): boolean;
    function pausePlay: boolean;
    function playCurrentItem: boolean;
    function playFirst: boolean;
    function playLast: boolean;
    function playNext: boolean;
    function playNextFolder: boolean;
    function playPrev: boolean;
    function playPrevFolder: boolean;
    function processKeyOp(const aKeyOp: TKeyOp; const aShiftState: TShiftState; const aKey: WORD): boolean;
    function renameFile(const aFilePath: string): boolean;
    function reverseSlideshow: boolean;
    function saveCopyFile(const aFilePath: string): boolean;
    function saveMoveFile(const aFilePath: string; const aFolder: string; const aOpText: string): boolean;
    function saveMoveFileToFolder(const aFilePath: string; const aFolder: string; const aOpText: string; const aRecordUndo: boolean = TRUE): boolean;
    function showHost(const aHostType: THostType): boolean;
    function showPlaylist: boolean;
    function showSlideshowDirection: boolean;
    function speedDn: boolean;
    function speedReset: boolean;
    function speedUp: boolean;
    function takeScreenshot: string;
    function undoMove: string;
    function whichHost: THostType;
    function windowSize(const aKeyOp: TKeyOp): boolean;
  protected
    procedure CreateParams(var params: TCreateParams); override;
    procedure onThumbClick(sender: TObject);
    procedure WMMove(var Message: TMessage) ; message WM_MOVE;
  public
    function initThumbnails(const aFilePath: string; const aRect: TRect): boolean;
  end;

function showThumbs(const aFilePath: string; const aRect: TRect): boolean;

implementation

uses
  mmpMPVCtrls, mmpMPVProperties,
  mmpDesktopUtils, mmpDialogs, mmpFileUtils, mmpFolderNavigation, mmpMathUtils, mmpPanelCtrls, mmpTicker, mmpUserFolders, mmpUtils, mmpWindowCtrls,
  formAboutBox, formHelp, formPlaylist,
  TGlobalVarsClass, TMediaInfoClass, TSendAllClass, TUndoMoveClass,
  _debugWindow, RTTI;

function showThumbs(const aFilePath: string; const aRect: TRect): boolean;
begin
  var vTF := TThumbsForm.create(NIL);
  try
    vTF.initThumbnails(aFilePath, aRect);
    GV.showingThumbs := TRUE;
    vTF.showModal;
  finally
    vTF.free;
    GV.showingThumbs := FALSE;
  end;
end;

{$R *.dfm}

function TThumbsForm.adjustAspectRatio: boolean;
var
  vWidth:  integer;
  vHeight: integer;
begin
  case (MI.imageWidth <= 0) OR (MI.imageHeight <= 0) of TRUE: EXIT; end;

  var vRatio := MI.imageHeight / MI.imageWidth;

  mmpWndWidthHeight(SELF.handle, vWidth, vHeight);

  vWidth  := trunc(vHeight / mmpAspectRatio(MI.imageWidth, MI.imageHeight));
  vHeight := trunc(vWidth * vRatio) + 2;

  SetWindowPos(SELF.Handle, HWND_TOP, (mmpScreenWidth - vWidth) div 2, (mmpScreenHeight - vHeight) div 2, vWidth, vHeight, SWP_NOMOVE); // resize window

  case GV.autoCentre of TRUE: autoCentre; end;
end;

procedure TThumbsForm.applicationEventsHint(Sender: TObject);
begin
  case length(application.hint) > 1 of
    TRUE: case application.hint[1] = '$' of TRUE: FThumbs.setPanelText(copy(application.hint, 2, MAXINT), -1, TRUE);
                                           FALSE: mmpSetPanelText(FStatusBar, pnTick, application.hint); end;end;
end;

function TThumbsForm.autoCentre: boolean;
begin
  case GV.autoCentre of TRUE: mmpCentreWindow(SELF.handle); end;
end;

function TThumbsForm.checkWindowSize(const aCtrlKeyDown: boolean): boolean;
begin
  result := TRUE;
  case aCtrlKeyDown of FALSE: EXIT; end;
  result := NOT ((FThumbs.thumbColCount = 1) or (FThumbs.thumbRowCount = 1))
end;

procedure TThumbsForm.CreateParams(var params: TCreateParams);
begin
  inherited;
  params.exStyle := params.exStyle OR WS_EX_APPWINDOW; // put an icon on the taskbar for the user
end;

function TThumbsForm.deleteCurrentItem: boolean;
begin
  case FThumbs.playlist.hasItems of FALSE: EXIT; end;

  var vShiftState := mmpShiftState;

  var vMsg := 'DELETE '#13#10#13#10'Folder: ' + extractFilePath(FThumbs.playlist.currentItem);
  case ssCtrl in vshiftState of  TRUE: vMsg := vMsg + '*.*';
                                FALSE: vMsg := vMsg + #13#10#13#10'File: ' + extractFileName(FThumbs.playlist.currentItem); end;

  case mmpShowOkCancelMsgDlg(vMsg) = IDOK of TRUE:  begin
                                                      var vIx := FThumbs.playlist.currentIx;
                                                      mmpDeleteThisFile(FThumbs.playlist.currentItem, vShiftState);
                                                      FThumbs.playlist.delete(FThumbs.playlist.currentIx);  // this decrements PL's FPlayIx...
                                                      case (ssCtrl in vShiftState) or (NOT FThumbs.playlist.hasItems) of TRUE: begin close; SA.postToAll(WIN_CLOSEAPP); end;
                                                                                                     FALSE: begin
                                                                                                              loadPlaylistWindow;
                                                                                                              case vIx = 0 of  TRUE: playCurrentItem;
                                                                                                                              FALSE: playNext; end;end;end;end;end; // ...hence, playNext
end;

procedure TThumbsForm.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  case mpv            = NIL of FALSE: freeAndNIL(mpv); end;      // do this first or the user will briefly see the blank form background
  case FMPVHost       = NIL of FALSE: freeAndNIL(FMPVHost); end;
  case FThumbs        = NIL of FALSE: freeAndNIL(FThumbs); end;
  case FProgressForm  = NIL of FALSE: freeAndNIL(FProgressForm); end;
  shutHelp;
end;

procedure TThumbsForm.FormCreate(Sender: TObject);
begin
  FMPVHost := TMPVHost.create(SELF);
  FMPVHost.parent := SELF;
  FMPVHost.OnOpenFile := onOpenFile;

  mmpInitStatusBar(FStatusBar);

  mpvCreate(mpv);
  mpv.onInitMPV    := onInitMPV;
  mpv.OnStateChged := onStateChange;
  mpvInitPlayer(mpv, FMPVHost.handle, '', extractFilePath(paramStr(0)));  // THIS RECREATES THE INTERNAL MPV OBJECT in TMPVBasePlayer
  mpvToggleRepeat(mpv); // so that any GIFs will remain visible rather than going black after one cycle

  var vImageDisplayDuration: string;
  mpvGetPropertyString(mpv, 'image-display-duration', vImageDisplayDuration);
  FImageDisplayDurationMs := strToFloatDef(vImageDisplayDuration, IMAGE_DISPLAY_DURATION) * 1000;
  FSlideshowDirection     := sdForwards;
end;

procedure TThumbsForm.FormResize(Sender: TObject);
begin
  case FThumbs = NIL of TRUE:  EXIT; end;
  case FShowing      of FALSE: EXIT; end; // ignore the initial resizing while the form starts up
  case whichHost of htThumbsHost: playCurrentItem; end;
  moveHelpWindow;
end;

procedure TThumbsForm.FormShow(Sender: TObject);
begin
  FThumbs := TThumbs.create;
  FThumbs.initThumbs(FMPVHost, FThumbsHost, FStatusBar);
  FThumbs.onThumbClick := onThumbClick;
  FProgressForm := TProgressForm.create(NIL);
  try
    FProgressForm.modal               := FALSE;
    FProgressForm.buttons             := FALSE;
    FProgressForm.heading.caption     := 'MMP Image Browser';
    FProgressForm.subHeading.caption  := 'Creating Thumbnails';
    FProgressForm.show;
    mmpProcessMessages;
    setWindowPos(FProgressForm.handle, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOSIZE + SWP_NOMOVE);
    timer.enabled := TRUE;
  finally
  end;
  setWindowPos(GV.mainForm.handle, HWND_TOP, 0, 0, 0, 0, SWP_NOSIZE + SWP_NOMOVE); // prevent mainForm from dropping down the Z-Order when progressForm closes
end;

function TThumbsForm.initThumbnails(const aFilePath: string; const aRect: TRect): boolean;
begin
  FInitialFilePath := aFilePath;

  SELF.top    := aRect.top;
  SELF.left   := aRect.left;
  SELF.width  := aRect.width;
  SELF.height := aRect.height;

  case GV.autoCentre of TRUE: autoCentre; end;

  SELF.borderIcons   := [biSystemMenu, biMaximize];
  SELF.borderStyle   := bsSizeable;
  SELF.borderWidth   := 0;
  SELF.color         := clBlack;

  FMPVHost.align      := alClient;
  FThumbsHost.align   := alClient;

  FMPVHost.visible    := FALSE;
  FThumbsHost.visible := TRUE;

  FThumbsHost.styleElements  := [];
  FThumbsHost.bevelOuter     := bvNone;
  FThumbsHost.color          := clBlack;
end;


function TThumbsForm.keepFile(const aFilePath: string): boolean;
var
  vNewName: string;
begin
  case FThumbs.playlist.hasItems of FALSE: EXIT; end;

  vNewName := mmpRenameFile(aFilePath, '_' + mmpFileNameWithoutExtension(aFilePath));
  case vNewName <> aFilePath of  TRUE: begin
                                        FThumbs.playlist.replaceCurrentItem(vNewName);
                                        mmpSetPanelText(FStatusBar, pnHelp, 'Kept'); end;
                                FALSE:  mmpSetPanelText(FStatusBar, pnHelp, 'NOT Kept'); end;
end;

function TThumbsForm.maximizeWindow: boolean;
// maximize to the largest size given the screen height,
// while maintaing the correct aspect ratio, width-wise, for the image dimensions
var
  vWidth:  integer;
  vHeight: integer;
begin
  case (MI.imageWidth <= 0) OR (MI.imageHeight <= 0) of TRUE: EXIT; end;

  var vRatio := MI.imageHeight / MI.imageWidth;

  vHeight := mmpScreenHeight - 50;

  vWidth  := trunc(vHeight / mmpAspectRatio(MI.imageWidth, MI.imageHeight));
  SetWindowPos(SELF.Handle, HWND_TOP, (mmpScreenWidth - vWidth) div 2, (mmpScreenHeight - vHeight) div 2, vWidth, vHeight, SWP_NOSIZE); // center window
  application.ProcessMessages;
  SetWindowPos(SELF.Handle, HWND_TOP, (mmpScreenWidth - vWidth) div 2, (mmpScreenHeight - vHeight) div 2, vWidth, vHeight, SWP_NOMOVE); // resize window
end;

function TThumbsForm.minimizeWindow: boolean;
begin
  SELF.windowState := TWindowState.wsMinimized;
end;

function TThumbsForm.moveHelpWindow(const aCreateNew: boolean = FALSE): boolean;
var vHostPanel: TPanel;
begin
  case FThumbs = NIL of TRUE: EXIT; end;
  case FShowing      of FALSE: EXIT; end; // ignore the initial resizing while the form starts up

  case whichHost of htMPVHost:    vHostPanel := FMPVHost;
                    htThumbsHost: vHostPanel := FThumbsHost; end;

  var vPt := FThumbsHost.ClientToScreen(point(vHostPanel.left + vHostPanel.width + 1, vHostPanel.top - 2 - mmpCaptionHeight - mmpBorderWidth)); // screen position of the top right corner of the application window, roughly.
  showHelp(SELF.handle, vPt, htImages, aCreateNew);
end;

procedure TThumbsForm.onInitMPV(sender: TObject);
//===== THESE CAN ALL BE OVERRIDDEN IN MPV.CONF =====
begin
  mpvSetDefaults(mpv, extractFilePath(paramStr(0)));
end;

procedure TThumbsForm.onOpenFile(const aURL: string);
begin
  tickerStart;
  try
    mpvOpenFile(mpv, aURL); // don't blink!
    mmpProcessMessages;
  except end;
  tickerStop;

  MI.initMediaInfo(aURL);

  showHost(htMPVHost);

  FThumbs.setPanelText(aURL, tickerTotalMs);
end;

procedure TThumbsForm.onStateChange(cSender: TObject; eState: TMPVPlayerState);
var vState: string;
begin
//  vState := TRttiEnumerationType.getName(eState);
//  debugString('onStateChange', vState);

//  case GV.playingSlideshow of FALSE: EXIT; end; // ?? Do we still need this ??

  case eState of
    mpsLoading: {FLocked := TRUE}; // ignore rapid keystrokes like held down left and right arrows until mpv has finished displaying each image, then continue
    mpsPlay,  {: FLocked := FALSE;} // EXPERIMENTAL COMBINE THE TWO
    mpsEnd: begin FLocked := FALSE; // we don't always get an mpsEnd event!
    {mpsEnd , mpsStop:} case GV.playingSlideshow of TRUE: begin mmpDelay(trunc(FImageDisplayDurationMs));
                                                                case GV.playingSlideshow of
                                                                  TRUE: case FSlideshowDirection of
                                                                               sdForwards:  case playNext of FALSE: playFirst; end;
                                                                               sdBackwards: case playPrev of FALSE: playLast;  end;
                                                                        end;end;end;end;end;
            end;
  mmpProcessMessages;
end;

procedure TThumbsForm.onThumbClick(sender: TObject);
begin
  FThumbs.cancel;
  mmpResetPanelHelp(FStatusBar);
  showHost(htMPVHost);
  FThumbs.playlist.setIx(TControl(sender).tag);
  playCurrentItem;
end;

function TThumbsForm.pausePlay: boolean;
begin
  GV.playingSlideshow := NOT GV.playingSlideshow;

  case NOT GV.playingSlideshow of TRUE: mmpCancelDelay; end;

  case GV.playingSlideshow of  TRUE: mpvSetPropertyString(mpv, 'image-display-duration', intToStr(trunc(FImageDisplayDurationMs) div 1000)); // doesn't really matter as long as it's valid and not 'inf'
                              FALSE: mpvSetPropertyString(mpv, 'image-display-duration', 'inf'); end;

  case GV.playingSlideshow of  TRUE: showSlideshowDirection;
                              FALSE: mmpSetPanelText(FStatusBar, pnHelp, 'PAUSED'); end;

  case GV.playingSlideshow of  TRUE: FThumbs.playCurrentItem; end;
end;

function TThumbsForm.playCurrentItem: boolean;
begin
  case whichHost of
    htMPVHost:    begin FLocked := TRUE; FThumbs.playCurrentItem; FThumbs.setPanelText(FThumbs.playlist.currentItem, -1, TRUE); end;
    htThumbsHost: FThumbs.playThumbs;
  end;
end;

function TThumbsForm.playFirst: boolean;
begin
  FThumbs.playlist.first;
  case whichHost of
    htMPVHost:    playCurrentItem;
    htThumbsHost: playCurrentItem;
  end;
end;

function TThumbsForm.playLast: boolean;
begin
  FThumbs.playlist.last;
  case whichHost of
    htMPVHost:    playCurrentItem;
    htThumbsHost: playCurrentItem;
  end;
end;

function TThumbsForm.playNext: boolean;
begin
  case whichHost of
    htMPVHost:    begin result := FThumbs.playlist.next; FLocked := result; case FLocked of TRUE: playCurrentItem; end;end;
    htThumbsHost: case NOT FThumbs.playlist.isLast of TRUE: playCurrentItem; end;
  end;
end;

function TThumbsForm.playNextFolder: boolean;
var
  nextFolder: string;
begin
  nextFolder := mmpNextFolder(FThumbs.currentFolder, nfForwards);
  case NextFolder = '' of FALSE: FThumbs.playThumbs(NextFolder + '$$$.$$$', ptPlaylistOnly); end; // because extractFilePath needs a file name ;)
  mpvStop(mpv); // if the folder is empty we want a blank screen
  playCurrentItem;
end;

function TThumbsForm.playPrev: boolean;
begin
  case whichHost of
    htMPVHost:    begin result := FThumbs.playlist.prev; FLocked := result; case FLocked of TRUE: playCurrentItem; end;end;
    htThumbsHost: case FThumbs.playlist.currentIx = FThumbs.thumbsPerPage of FALSE: FThumbs.playPrevThumbsPage; end;
  end;
end;

function TThumbsForm.playPrevFolder: boolean;
var
  prevFolder: string;
begin
  prevFolder := mmpNextFolder(FThumbs.currentFolder, nfBackwards);
  case prevFolder = '' of FALSE: FThumbs.playThumbs(prevFolder + '$$$.$$$', ptPlaylistOnly); end; // because extractFilePath needs a file name ;)
  mpvStop(mpv); // if the folder is empty we want a blank screen
  playCurrentItem;
end;

function TThumbsForm.showHost(const aHostType: THostType): boolean;
begin
  FMPVHost.visible    := aHostType = htMPVHost;
  FThumbsHost.visible := aHostType = htThumbsHost;
end;

function TThumbsForm.renameFile(const aFilePath: string): boolean;
var
  vNewName: string;
begin
  case FThumbs.playlist.hasItems of FALSE: EXIT; end;

  vNewName := mmpRenameFile(aFilePath);
  case vNewName = aFilePath of FALSE: begin
                                        FThumbs.playlist.replaceCurrentItem(vNewName);
                                        mmpSetPanelText(FStatusBar, pnSave, 'Renamed: ' + aFilePath); end;end;
  mmpSetPanelText(FStatusBar, pnName, extractFileName(vNewName));
end;

function TThumbsForm.reverseSlideshow: boolean;
begin
  FSlideshowDirection := TSlideshowDirection(1 - ord(FSlideshowDirection)); // x := 1 - x
  showSlideshowDirection;
  case GV.playingSlideshow of FALSE: pausePlay; end;
end;

function TThumbsForm.saveCopyFile(const aFilePath: string): boolean;
begin
  case mmpCopyFile(aFilePath, mmpUserDstFolder('Copied'), FALSE, FALSE) of
                                                   TRUE:  begin
                                                            mmpSetPanelText(FStatusBar, pnHelp, 'Copied');
                                                            mmpSetPanelText(FStatusBar, pnSave, 'Copied to: ' + extractFilePath(aFilePath));
                                                          end;
                                                  FALSE:  begin
                                                            mmpSetPanelOwnerDraw(FStatusBar, pnHelp, TRUE);
                                                            mmpSetPanelText(FStatusBar, pnHelp, 'NOT Copied');
                                                            end;end;
end;

function TThumbsForm.saveMoveFile(const aFilePath, aFolder, aOpText: string): boolean;
begin
  case saveMoveFileToFolder(aFilePath, aFolder, aOpText) of FALSE: EXIT; end;
  FThumbs.playlist.delete(FThumbs.playlist.currentIx);
  playCurrentItem;
end;

function TThumbsForm.saveMoveFileToFolder(const aFilePath: string; const aFolder: string; const aOpText: string; const aRecordUndo: boolean = TRUE): boolean;
begin
  result := mmpCopyFile(aFilePath, aFolder, TRUE, aRecordUndo);
  case result of  TRUE: begin
                          mmpSetPanelText(FStatusBar, pnHelp, aOpText);
                          mmpSetPanelText(FStatusBar, pnSave, aOpText + ' to: ' + aFolder);
                          FThumbs.savePanelReserved := TRUE;
                        end;
                FALSE:  begin
                          mmpSetPanelOwnerDraw(FStatusBar, pnHelp, TRUE);
                          mmpSetPanelText(FStatusBar, pnHelp, 'NOT ' + aOpText);
                        end;end;
end;

function TThumbsForm.showPlaylist: boolean;
begin
  EXIT; // EXPERIMENTAL
  var vPt := FThumbsHost.ClientToScreen(point(FThumbsHost.left + FThumbsHost.width, FThumbsHost.top - 2)); // screen position of the top right corner of the application window, roughly.
  formPlaylist.showPlaylist(FThumbs.playlist, vPt, FThumbsHost.height, TRUE);
end;

function TThumbsForm.showSlideshowDirection: boolean;
begin
  case FSlideshowDirection of
    sdForwards:   mmpSetPanelText(FStatusBar, pnHelp, 'Slideshow ->');
    sdBackwards:  mmpSetPanelText(FStatusBar, pnHelp, '<- Slideshow'); end;
end;

function TThumbsForm.speedDn: boolean;
begin
  FImageDisplayDurationMs := FImageDisplayDurationMs + 100;
  mmpSetPanelText(FStatusBar, pnHelp, format('%dms', [trunc(FImageDisplayDurationms)]));
end;

function TThumbsForm.speedReset: boolean;
begin
  FImageDisplayDurationMs := IMAGE_DISPLAY_DURATION * 1000;
  mmpSetPanelText(FStatusBar, pnHelp, format('%dms', [trunc(FImageDisplayDurationMs)]));
end;

function TThumbsForm.speedUp: boolean;
begin
  case FImageDisplayDurationMs = 100 of TRUE: EXIT; end;
  FImageDisplayDurationMs := FImageDisplayDurationMs - 100;
  mmpSetPanelText(FStatusBar, pnHelp, format('%dms', [trunc(FImageDisplayDurationMs)]));
end;

procedure TThumbsForm.FStatusBarDrawPanel(StatusBar: TStatusBar; Panel: TStatusPanel; const Rect: TRect);
// only called for panelVers which has style set to psOwnerDraw at app launch. This is changed in TPanelCtrl.ShowThumbsPageNo
begin
  statusBar.canvas.font.style   := [fsBold];
  statusBar.canvas.brush.color  := clMaroon;
  statusBar.canvas.fillRect(rect);
  var vCenterX: integer := (rect.right - rect.left - statusBar.canvas.textWidth(panel.text)) div 2;
  var vCenterY: integer := (rect.bottom - rect.top - statusBar.canvas.textHeight(panel.text)) div 2;
  textOut(statusBar.canvas.handle, rect.left + vCenterX, rect.top + vCenterY, PChar(panel.text), length(panel.text));
end;

procedure TThumbsForm.FStatusBarResize(Sender: TObject);
begin
  mmpResizeStatusBar(FStatusBar);
end;

function TThumbsForm.takeScreenshot: string;
begin
  case whichHost of htThumbsHost: EXIT; end;
  var vScreenshotDirectory: string;
  mpvGetPropertyString(mpv, 'screenshot-directory', vScreenshotDirectory);

  case vScreenshotDirectory = '' of  TRUE: result := mpvTakeScreenshot(mpv, extractFilePath(mpvFileName(mpv)));   // otherwise screenshots of an image go to Windows/System32 !!
                                    FALSE: result := mpvTakeScreenshot(mpv, vScreenshotDirectory); end;
end;

procedure TThumbsForm.timerTimer(Sender: TObject);
begin
  timer.enabled := FALSE;
  case GV.mainForm <> NIL of TRUE: GV.mainForm.hide; end;
  case GV.mainForm <> NIL of TRUE: showWindow(GV.mainForm.handle, SW_HIDE); end; // UI.delayedHide doesn't always work - the delay might be being optimized out
  FShowing := TRUE;
  freeAndNIL(FProgressForm);
  FThumbs.playThumbs(FInitialFilePath);
end;

function TThumbsForm.undoMove: string;
var
  vSrcFilePath: string;
  vDstFilePath: string;
begin
  case UM.undoPop(vSrcFilePath, vDstFilePath) of  TRUE: case saveMoveFileToFolder(vSrcFilePath, extractFilePath(vDstFilePath), 'Undone', FALSE)
                                                            of TRUE:  begin
                                                                        FThumbs.playlist.insert(vDstFilePath);
                                                                        FThumbs.playlist.find(vDstFilePath);
                                                                        FThumbs.playCurrentItem; end;end;
                                                 FALSE: mmpSetPanelText(FStatusBar, pnHelp, 'Nothing to Undo'); end;
end;

function TThumbsForm.whichHost: THostType;
begin
  case FThumbsHost.visible of  TRUE: result := htThumbsHost;  end;
  case FMPVHost.visible    of  TRUE: result := htMPVHost;     end;
end;

function TThumbsForm.windowSize(const aKeyOp: TKeyOp): boolean;
var dxy: integer;
begin
  case ssShift in mmpShiftState of  TRUE: dxy := 10;
                                   FALSE: dxy := 1; end;

  case aKeyOp of
    koWindowShorter:  SELF.height := SELF.height - dxy;
    koWindowTaller:   SELF.height := SELF.height + dxy;
    koWindowNarrower: SELF.width  := SELF.width  - dxy;
    koWindowWider:    SELF.width  := SELF.width  + dxy;
  end;
end;

procedure TThumbsForm.WMMove(var Message: TMessage);
begin
  case FThumbs = NIL of TRUE: EXIT; end;
  case FShowing      of FALSE: EXIT; end; // ignore the initial resizing while the form starts up
  moveHelpWindow;
  GV.autoCentre := FALSE;
end;

//==========

procedure TThumbsForm.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  case whichHost of htMPVHost: mmpResetPanelHelp(FStatusBar); end; // don't obliterate thumbnail page numbers

  case (key in [VK_LEFT, VK_RIGHT]) and FLocked of TRUE: begin key := 0; EXIT; end;end;

  var vKeyOp: TKeyOp := processKeyStroke(mpv, key, shift, kdDn);

  case (key in [VK_UP, VK_DOWN, VK_LEFT, VK_RIGHT]) and (NOT (ssCtrl in shift)) and mpvAdjusted(mpv)
    of  TRUE: begin
                FKeyHandled := TRUE; // don't let the user accidentally change folders or image with the arrow keys after adjusting the image somehow
                EXIT; end;end;

  FKeyHandled := processKeyOp(vKeyOp, shift, key);
end;

procedure TThumbsForm.FormKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  case (key in [VK_LEFT, VK_RIGHT]) and FLocked of TRUE: begin key := 0; EXIT; end;end;
  case FKeyHandled of TRUE: EXIT; end; //  Keys that can be pressed singly or held down for repeat action: don't process the KeyUp as well as the KeyDown
  processKeyOp(processKeyStroke(mpv, key, shift, kdUp), shift, key);
  case key in [VK_F10..VK_F12] of TRUE: key := 0; end; // Disable the [notorious] Windows "sticky" nature of F10
end;

function TThumbsForm.processKeyOp(const aKeyOp: TKeyOp; const aShiftState: TShiftState; const aKey: WORD): boolean;
begin
  result := FALSE;

  var vIx := FThumbs.currentIx;

  case aKeyOp of
    koNone:         EXIT;   // key not processed. bypass setting result to TRUE

    koAboutBox:           showAboutBox;
    koAdjustAspectRatio:  case whichHost of htMPVHost: adjustAspectRatio; end;
    koAllReset:           begin mpvBrightnessReset(mpv); mpvContrastReset(mpv); mpvGammaReset(mpv); mpvPanReset(mpv); mpvRotateReset(mpv); mpvSaturationReset(mpv); mpvZoomReset(mpv); end;
    koBrightnessUp:       mpvBrightnessUp(mpv);
    koBrightnessDn:       mpvBrightnessDn(mpv);
    koBrightnessReset:    mpvBrightnessReset(mpv);
    koCentreWindow:       mmpCentreWindow(SELF.handle);
    koClipboard:          case whichHost of htMPVHost: FThumbs.playlist.copyToClipboard; end;
    koCloseAll:           begin mmpCancelDelay; FThumbs.cancel; close; SA.postToAll(WIN_CLOSEAPP, TRUE); end;
    koCloseImageBrowser:  begin mmpCancelDelay; FThumbs.cancel; close; end;
    koContrastUp:         mpvContrastUp(mpv);
    koContrastDn:         mpvContrastDn(mpv);
    koContrastReset:      mpvContrastReset(mpv);
    koDeleteCurrentItem:  case whichHost of htMPVHost: deleteCurrentItem; end;
    koGammaUp:            mpvGammaUp(mpv);
    koGammaDn:            mpvGammaDn(mpv);
    koGammaReset:         mpvGammaReset(mpv);
    koGreaterWindow:      case checkWindowSize(ssCtrl in aShiftState) of TRUE: begin mmpGreaterWindow(SELF.handle, aShiftState, FThumbs.thumbSize); autoCentre; end;end;
    koKeep:               keepFile(FThumbs.playlist.currentItem);
    koMaximize:           maximizeWindow;
    koMinimizeWindow:     minimizeWindow;
    koMoveToKeyFolder:    case whichHost of htMPVHost: saveMoveFile(FThumbs.playlist.currentItem, mmpUserDstFolder(mmpFolderFromFKey(aKey)), 'Moved'); end;
    koNextFolder:         playNextFolder;
    koPanLeft:            mpvPanLeft(mpv);
    koPanRight:           mpvPanRight(mpv);
    koPanUp:              mpvPanUp(mpv);
    koPanDn:              mpvPanDn(mpv);
    koPanReset:           mpvPanReset(mpv);
    koPausePlay:          case whichHost of htMPVHost: pausePlay; end;
    koPlayFirst:          playFirst;
    koPlayLast:           playLast;
    koPlayNext:           playNext;
    koPlayPrev:           playPrev;
    koPlayThumbs:         begin showHost(htThumbsHost); FThumbs.playThumbs; end;
    koPrevFolder:         playPrevFolder;
    koReloadPlaylist:     FThumbs.playThumbs(FThumbs.playlist.currentFolder, ptPlaylistOnly);
    koRenameFile:         case whichHost of htMPVHost: renameFile(FThumbs.playlist.currentItem); end;
    koReverseSlideshow:   case whichHost of htMPVHost: reverseSlideshow; end;
    koRotateR:            mpvRotateRight(mpv);
    koRotateL:            mpvRotateLeft(mpv);
    koRotateReset:        mpvRotateReset(mpv);
    koSaturationUp:       mpvSaturationUp(mpv);
    koSaturationDn:       mpvSaturationDn(mpv);
    koSaturationReset:    mpvSaturationReset(mpv);
    koSaveCopy:           case whichHost of htMPVHost: saveCopyFile(FThumbs.playlist.currentItem); end;
    koSaveMove:           case whichHost of htMPVHost: saveMoveFile(FThumbs.playlist.currentItem, mmpUserDstFolder('Saved'), 'Saved'); end;
    koScreenshot:         takeScreenshot;
    koSpeedDn:            speedDn;
    koSpeedReset:         speedReset;
    koSpeedUp:            speedUp;
    koThumbsDn:           case whichHost of htThumbsHost: begin FThumbs.thumbSize := FThumbs.thumbSize - 10; FThumbs.playThumbs; end;end;
    koThumbsUp:           case whichHost of htThumbsHost: begin FThumbs.thumbSize := FThumbs.thumbSize + 10; FThumbs.playThumbs; end;end;
    koToggleHelp:         case GV.showingHelp of TRUE: shutHelp; FALSE: moveHelpWindow(TRUE); end;
    koUndoMove:           undoMove;
    koZoomIn:             mpvZoomIn(mpv);
    koZoomOut:            mpvZoomOut(mpv);
    koZoomReset:          mpvZoomReset(mpv);

    koWindowShorter,
    koWindowTaller,
    koWindowNarrower,
    koWindowWider:        {case whichHost of htMPVHost:} windowSize(aKeyOp); {end;}

    koShowCaption:;
    koFullscreen:;
    koToggleControls:;
    koToggleBlackout:;
    koBrighterPB:;
    koDarkerPB:;
    koTogglePlaylist:     showPlaylist;
  end;

  case whichHost of htThumbsHost: case vIx = FThumbs.currentIx of FALSE:  begin // has the thumbnail page been recreated starting at a different item Ix ?
                                                                            FThumbsHost.refresh;
                                                                            application.processMessages; end;end;end;

  result := TRUE; // key was processed
end;

end.

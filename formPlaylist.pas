{   MMP: Minimalist Media Player
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
unit formPlaylist;

interface

uses
  winApi.messages, winApi.windows,
  system.sysUtils, system.variants, system.classes,
  vcl.comCtrls, vcl.controls, vcl.dialogs, vcl.extCtrls, vcl.forms, vcl.graphics, vcl.imaging.pngImage, vcl.stdCtrls,
  TPlaylistClass;

type
  TPlaylistForm = class(TForm)
    backPanel: TPanel;
    buttonPanel: TPanel;
    shiftLabel: TLabel;
    moveLabel: TLabel;
    LB: TListBox;
    procedure FormCreate(Sender: TObject);
    procedure LBDblClick(Sender: TObject);
    procedure LBKeyPress(Sender: TObject; var Key: Char);
    procedure LBKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
  private
    FPL: TPlaylist;
    function  ctrlKeyDown: boolean;
    function  isItemVisible: boolean;
    function  playItemIndex(const aItemIndex: integer): boolean;
    function  visibleItemCount: integer;
  protected
    procedure CreateParams(var Params: TCreateParams);
  public
    function  clearPlaylistBox: boolean;
    function  highlightCurrentItem: boolean;
    function  loadPlaylistBox(const forceReload: boolean = FALSE): boolean;
    property  playlist: TPlaylist read FPL write FPL;
  end;

function focusPlaylist: boolean;
function loadPlaylistWindow(const forceReload: boolean = FALSE): boolean;
function showingPlaylist: boolean;
function showPlaylist(const aPL: TPlaylist; const Pt: TPoint; const aHeight: integer; const createNew: boolean = TRUE): boolean;
function shutPlaylist: boolean;

implementation

uses
  winApi.shellApi,
  system.strUtils,
  mmpconsts, mmpSingletons, mmpUtils,
  _debugWindow;

var
  playlistForm: TPlaylistForm;

function focusPlaylist: boolean;
begin
  case playlistForm = NIL of TRUE: EXIT; end;
  setForegroundWindow(playlistForm.handle); // so this window also receives keyboard keystrokes
end;

function loadPlaylistWindow(const forceReload: boolean = FALSE): boolean;
begin
  case GV.showingPlaylist of FALSE: EXIT; end;
  case playlistForm = NIL of FALSE: playlistForm.loadPlaylistBox(forceReload); end;
end;

function showingPlaylist: boolean;
begin
  result := playlistForm <> NIL;
end;

function showPlaylist(const aPL: TPlaylist; const Pt: TPoint; const aHeight: integer; const createNew: boolean = TRUE): boolean;
begin
  case (playlistForm = NIL) and createNew of TRUE: playlistForm := TPlaylistForm.create(NIL); end;
  case playlistForm = NIL of TRUE: EXIT; end; // createNew = FALSE and there isn't a current playlist window. Used for repositioning the window when the main UI moves or resizes.

  case aHeight > UI_DEFAULT_AUDIO_HEIGHT of TRUE: playlistForm.height := aHeight; end;
  screen.cursor := crDefault;

  playlistForm.playlist := aPL;

  case aPL.hasItems of  TRUE: playlistForm.loadPlaylistBox;
                       FALSE: playlistForm.clearPlaylistBox; end;
  playlistForm.show;

  winAPI.Windows.setWindowPos(playlistForm.handle, HWND_TOP, Pt.X, Pt.Y, 0, 0, SWP_SHOWWINDOW + SWP_NOSIZE);
  focusPlaylist;

  case aPL.hasItems of TRUE: playlistForm.highlightCurrentItem; end;

  GV.showingPlaylist := TRUE;
end;

function shutPlaylist: boolean;
begin
  case playlistForm <> NIL of TRUE: begin playlistForm.close; playlistForm.free; playlistForm := NIL; end;end;
  playlistForm := NIL;
  GV.showingPlaylist := FALSE;
end;

{$R *.dfm}

function TPlaylistForm.clearPlaylistBox: boolean;
begin
  playlistForm.LB.items.clear;
  mmpProcessMessages;
end;

procedure TPlaylistForm.CreateParams(var Params: TCreateParams);
// no taskbar icon for the app
begin
  inherited;
  Params.ExStyle    := Params.ExStyle OR (WS_EX_APPWINDOW);
  Params.WndParent  := SELF.Handle; // normally application.handle
end;

procedure TPlaylistForm.FormCreate(Sender: TObject);
begin
  LB.align            := alClient;
  LB.bevelInner       := bvNone;
  LB.bevelOuter       := bvNone;
  LB.borderStyle      := bsNone;
  LB.margins.bottom   := 10;
  LB.margins.left     := 10;
  LB.margins.right    := 10;
  LB.margins.top      := 10;
  LB.AlignWithMargins := TRUE;

  SELF.width  := 556;
//  SELF.height := 840;

  SetWindowLong(handle, GWL_STYLE, GetWindowLong(handle, GWL_STYLE) OR WS_CAPTION AND (NOT (WS_BORDER)));
  color := DARK_MODE_DARK;

  styleElements     := []; // don't allow any theme alterations
  borderStyle       := bsNone;
  LB.onDblClick     := LBDblClick;
  LB.onKeyUp        := LBKeyUp;
end;

function TPlaylistForm.ctrlKeyDown: boolean;
begin
  result := getKeyState(VK_CONTROL) < 0;
end;

function TPlaylistForm.highlightCurrentItem: boolean;
begin
  LB.items.beginUpdate;
  try
    case LB.count > 0 of TRUE:  begin
                                  LB.itemIndex := FPL.currentIx;
                                  LB.selected[LB.itemIndex] := TRUE;
                                  case isItemVisible of TRUE: EXIT; end;
                                  var vTopIndex := LB.itemIndex - (visibleItemCount div 2); // try to position it in the middle of the listbox
                                  case vTopIndex >= 0 of  TRUE: LB.topIndex := vTopIndex;
                                                         FALSE: LB.topIndex := 0; end;end;end;
  finally
    LB.items.endUpdate;
  end;
end;

function TPlaylistForm.isItemVisible: boolean;
var
  vTopIndex, vVisibleItemCount: integer;
begin
  // Get the index of the top visible item
  vTopIndex := LB.topIndex;

  // Calculate the number of items that can fit in the visible area
  vVisibleItemCount := visibleItemCount;

  // Calculate the index of the bottom visible item: (TopIndex + VisibleItemCount - 1)
  result := (LB.itemIndex >= vTopIndex) and (LB.itemIndex <= vTopIndex + vVisibleItemCount - 1);
end;

procedure TPlaylistForm.LBDblClick(Sender: TObject);
begin
  playItemIndex(LB.itemIndex);
end;

procedure TPlaylistForm.LBKeyPress(Sender: TObject; var Key: Char);
begin
  key := #0;
end;

procedure TPlaylistForm.LBKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  case (key = VK_RETURN) and NOT ctrlKeyDown of TRUE: playItemIndex(LB.itemIndex); end;
end;

function TPlaylistForm.loadPlaylistBox(const forceReload: boolean = FALSE): boolean;
begin
  case FPL.hasItems of FALSE: begin clearPlaylistBox; EXIT; end;end;

  playlistForm.LB.items.beginUpdate; // prevent flicker when moving the window

  try
    case forceReload or (LB.items.count = 0) of TRUE: FPL.getPlaylist(LB); end;

    highlightCurrentItem;
  finally
    playlistForm.LB.items.endUpdate;
  end;
end;

function TPlaylistForm.playItemIndex(const aItemIndex: integer): boolean;
begin
  FPL.find(FPL.thisItem(aItemIndex));
  MP.play(FPL.currentItem);
  UI.movePlaylistWindow(FALSE); // should be TNotifyEvent!
end;

function TPlaylistForm.visibleItemCount: integer;
begin
  result := LB.clientHeight div LB.itemHeight;
end;

initialization
  playlistForm := NIL;

finalization
  case playlistForm <> NIL of TRUE: begin playlistForm.close; playlistForm.free; playlistForm := NIL; end;end;

end.

{   Minimalist Media Player
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
unit TThumbsClass;

interface

uses
  generics.collections,
  system.classes,
  vcl.comCtrls, vcl.controls, vcl.extCtrls, vcl.forms,
  mmpConsts,
  TMPVHostClass, TPlaylistClass, TThumbClass;

type
  TPlayType = (ptGenerateThumbs, ptPlaylistOnly);

  TThumbs = class(TObject)
  strict private
    FCancel: boolean;
    FCurrentFolder:     string;
    FMPVHost:           TMPVHost;
    FOnThumbClick:      TNotifyEvent;
    FPlaylist:          TPlaylist;
    FSavePanelReserved: boolean;
    FStatusBar:         TStatusBar;
    FThumbsHost:        TWinControl;
    FThumbs:            TObjectList<TThumb>;
    FThumbSize:         integer;
  private
    function  fillPlaylist(const aPlaylist: TPlaylist; const aFilePath: string; const aCurrentFolder: string): boolean;
    function  generateThumbs(const aItemIx: integer): integer;
    function  getCurrentIx: integer;
  public
    constructor create;
    destructor destroy; override;
    function cancel: boolean;
    function initThumbs(const aMPVHost: TMPVHost; const aThumbsHost: TWinControl; const aStatusBar: TStatusBar): boolean;
    function playCurrentItem: boolean;
    function playPrevThumbsPage: boolean;
    function playThumbs(const aFilePath: string = ''; const aPlayType: TPlayType = ptGenerateThumbs): integer;
    function setPanelText(const aURL: string; aTickCount: double = -1; const aGetMediaInfo: boolean = FALSE): boolean;
    function thumbsPerPage: integer;
    property currentFolder:     string        read FCurrentFolder;
    property currentIx:         integer       read getCurrentIx;
    property onThumbClick:      TNotifyEvent  read FOnThumbClick    write FOnThumbClick;
    property savePanelReserved: boolean                             write FSavePanelReserved;
    property playlist:          TPlaylist     read FPlaylist;
    property thumbSize:         integer       read FThumbSize       write FThumbSize;
    property statusBar:         TStatusBar                          write FStatusBar;
  end;

implementation

uses
  winApi.windows,
  system.sysUtils,
  {vcl.controls,} vcl.graphics,
  mmpMPVFormatting,
  mmpFileUtils, mmpPanelCtrls, mmpUtils,
  TGlobalVarsClass, TMediaInfoClass,
  _debugWindow;

{ TThumbs }

function TThumbs.cancel: boolean;
begin
  FCancel := TRUE;
end;

constructor TThumbs.create;
begin
  inherited;
  FPlaylist := TPlaylist.create;
  FThumbs := TObjectList<TThumb>.create;
  FThumbs.ownsObjects := TRUE;
  FThumbSize := THUMB_DEFAULT_SIZE;
end;

destructor TThumbs.destroy;
begin
  case FPlaylist  = NIL of FALSE: FPlaylist.free; end;
  case FThumbs    = NIL of FALSE: FThumbs.free;   end;
  inherited;
end;

function TThumbs.fillPlaylist(const aPlaylist: TPlaylist; const aFilePath: string; const aCurrentFolder: string): boolean;
begin
  case aPlaylist.hasItems AND (aPlaylist.currentFolder <> aCurrentFolder) of TRUE: aPlaylist.clear; end;
  case aPlaylist.hasItems of FALSE: aPlaylist.fillPlaylist(aCurrentFolder, [mtImage]); end;
  case aPlaylist.hasItems of TRUE:  aPlaylist.find(aFilePath); end;
  case aPlaylist.hasItems AND (aPlaylist.currentIx = -1) of TRUE: aPlaylist.first; end;
end;

function TThumbs.generateThumbs(const aItemIx: integer): integer;
var
  vThumbTop:  integer;
  vThumbLeft: integer;
  vIx:        integer;
  vDone:      boolean;

  function adjustCurrentItem: boolean;  // guarantee a full page of thumbnails on the last page
  begin
    case (FPlaylist.count - FPlaylist.currentIx) < thumbsPerPage of TRUE: FPlaylist.setIx(FPlaylist.count - thumbsPerPage); end;
  end;

  function calcNextThumbPosition: integer;
  begin
    vThumbLeft := vThumbLeft + FThumbSize + THUMB_MARGIN;
    case (vThumbLeft + FThumbSize) > FThumbsHost.width of
      TRUE: begin
              vThumbLeft  := THUMB_MARGIN;
              vThumbTop   := vThumbTop + FThumbSize + THUMB_MARGIN; end;end;
  end;

  function setPanelPageNo: boolean;
  var
    tpp: integer;
    extra: integer;
  begin
    tpp   := thumbsPerPage;
    extra := 0;
    case FPlaylist.count mod tpp > 0 of TRUE: extra := 1; end; // is there a remainder after fileCount div thumbsPerPage? If so, there's an extra page
    var vPageNo := FPlaylist.currentIx div tpp;
    case FPlaylist.isLast of TRUE: vPageNo := vPageNo + extra; end;
    mmpSetPanelText(FStatusBar, pnHelp, mmpFormatPageNumber(vPageNo, (FPlaylist.count div tpp) + extra));
  end;

begin
  FThumbs.clear;

  case FPlaylist.validIx(aItemIx) of FALSE: EXIT; end;

  adjustCurrentItem;

  vThumbTop  := THUMB_MARGIN;
  vThumbLeft := THUMB_MARGIN;

  repeat
    FThumbs.add(TThumb.create(FPlayList.currentItem, FThumbSize, FThumbSize));
    vIx := FThumbs.count - 1;

    FThumbs[vIx].top      := vThumbTop;
    FThumbs[vIx].left     := vThumbLeft;
    FThumbs[vIx].tag      := FPlaylist.currentIx;
    FThumbs[vIx].OnClick  := FOnThumbClick;
    FThumbs[vIx].hint     := '|$' + FPlaylist.currentItem;

    FThumbs[vIx].parent := FThumbsHost;  // delay to prevent flicker of top left thumbnail

    setPanelText(FPlaylist.currentItem);

    mmpProcessMessages; // show the thumbnails as they're drawn

    calcNextThumbPosition;

    vDone := NOT FPlaylist.next;
  until (vThumbTop + FThumbSize > FThumbsHost.height) OR vDone OR FCancel;

  setPanelPageNo;

  result := FPlaylist.currentIx;
end;

function TThumbs.getCurrentIx: integer;
begin
  result := FPlaylist.currentIx;
end;

function TThumbs.initThumbs(const aMPVHost: TMPVHost; const aThumbsHost: TWinControl; const aStatusBar: TStatusBar): boolean;
begin
  FMPVHost    := aMPVHost;
  FThumbsHost := aThumbsHost;
  FStatusBar  := aStatusBar;
end;

function TThumbs.playCurrentItem: boolean;
begin
  case FPlaylist.hasItems of TRUE: FMPVHost.openFile(FPlaylist.currentItem); end;
end;

function TThumbs.playPrevThumbsPage: boolean;
begin
  case FPlaylist.isFirst of FALSE:  begin
                                      FPlaylist.setIx(FPlaylist.currentIx - (thumbsPerPage * 2));
                                      playThumbs;
  end;end;
end;

function TThumbs.playThumbs(const aFilePath: string = ''; const aPlayType: TPlayType = ptGenerateThumbs): integer;
begin
  result := -1;
  case aFilePath <> '' of TRUE: begin
                                  FCurrentFolder := extractFilePath(aFilePath);                // need to keep track of current folder in case it contains no images
                                  mmpInitStatusBar(FStatusBar);
                                  mmpSetPanelText(FStatusBar, pnSave, FCurrentFolder);
                                  fillPlaylist(FPlaylist, aFilePath, FCurrentFolder); end;end; // in which case, the playlist's currentFolder will be void

  FCancel := FALSE;
//  debugInteger('StartIx', FPlaylist.currentIx);
  case aPlayType of ptGenerateThumbs: result := generateThumbs(FPlaylist.currentIx); end;
//  debugInteger('EndIx', FPlaylist.currentIx);

//  debugInteger('thumbsPP', thumbsPerPage);
  mmpProcessMessages; // force statusBar page number to display if the left or right arrow is held down (also displays file name and number)
end;

function TThumbs.setPanelText(const aURL: string; aTickCount: double = -1; const aGetMediaInfo: boolean = FALSE): boolean;
begin
  case FPlaylist.hasItems of  TRUE: mmpSetPanelText(FStatusBar, pnName, extractFileName(aURL));
                             FALSE: mmpSetPanelText(FStatusBar, pnName, THUMB_NO_IMAGES); end;

  case FPlaylist.hasItems of  TRUE: mmpSetPanelText(FStatusBar, pnNumb, mmpFormatFileNumber(FPlaylist.indexOf(aURL) + 1, FPlaylist.count));
                             FALSE: mmpSetPanelText(FStatusBar, pnNumb, mmpFormatFileNumber(0, 0)); end;

  case aGetMediaInfo      of  TRUE: case FPlaylist.hasItems of  TRUE: mmpSetPanelText(FStatusBar, pnSize, mmpFormatThumbFileSize(mmpFileSize(aURL)));
                                                               FALSE: mmpSetPanelText(FStatusBar, pnSize, mmpFormatThumbFileSize(0)); end;
                             FALSE: mmpSetPanelText(FStatusBar, pnSize, ''); end;


  case aGetMediaInfo      of  TRUE: case FPlaylist.hasItems of  TRUE: begin
                                                                        MI.initMediaInfo(aURL);
                                                                        mmpSetPanelText(FStatusBar, pnXXYY, format('%d x %d', [MI.imageWidth, MI.imageHeight]));
                                                                      end;
                                                               FALSE: mmpSetPanelText(FStatusBar, pnXXYY, ''); end;
                             FALSE: mmpSetPanelText(FStatusBar, pnXXYY, ''); end;

  case aTickCount <> -1 of TRUE: mmpSetPanelText(FStatusBar, pnTick, mmpFormatTickCount(aTickCount)); end;

  case FSavePanelReserved of  TRUE: FSavePanelReserved := FALSE;
                             FALSE: mmpSetPanelText(FStatusBar, pnSave, FPlaylist.currentFolder); end;
end;

function TThumbs.thumbsPerPage: integer;
begin
  result := ((FThumbsHost.width - THUMB_MARGIN) div (FThumbSize + THUMB_MARGIN)) * ((FThumbsHost.height - THUMB_MARGIN) div (FThumbSize + THUMB_MARGIN));
end;

end.

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
unit TPlaylistClass;

interface

uses
  system.classes, system.generics.collections,
  vcl.stdCtrls,
  mmpConsts;

type
  TSetOfMediaType = set of TMediaType;

  TPlaylist = class(TObject)
  strict private
    FCurrentFolder: string;
    FPlayIx: integer;
    FPlaylist: TList<string>;
  private
    function extractNumericPart(const aString: string): integer;
  public
    constructor create;
    destructor  Destroy; override;
    function add(const anItem: string): boolean;
    function clear: boolean;
    function count: integer;
    function copyToClipboard: boolean;
    function currentFolder: string;
    function currentItem: string;
    function currentIx: integer;
    function delete(const ix: integer = -1): boolean;
    function displayItem: string;
    function fillPlaylist(const aFolder: string; const aSetOfMediaType: TSetOfMediaType = [mtAudio, mtVideo, mtImage]): boolean;
    function find(const anItem: string): boolean;
    function first: boolean;
    function formattedItem: string;
    function getPlaylist(aListBox: TListBox): boolean;
    function hasItems: boolean;
    function indexOf(const anItem: string): integer;
    function insert(const anItem: string): boolean;
    function isFirst: boolean;
    function isLast: boolean;
    function last: boolean;
    function next: boolean;
    function prev: boolean;
    function replaceCurrentItem(const aNewItem: string): boolean;
    function setIx(const ix: integer): integer;
    function sort: boolean;
    function thisItem(const ix: integer): string;
    function validIx(const ix: integer): boolean;
  end;

implementation

uses
  winApi.windows,
  system.regularExpressions, system.sysUtils,
  vcl.clipbrd,
  mmpFileUtils, mmpSingletons, mmpUtils,
  formCaptions,
  TListHelperClass,
  _debugWindow;

{ TPlaylist }

function TPlaylist.add(const anItem: string): boolean;
begin
  FPlayList.add(anItem);
end;

function TPlaylist.clear: boolean;
begin
  FPlaylist.clear;
  FPlayIx := -1;
end;

function TPlaylist.copyToClipboard: boolean;
begin
  result := FALSE;
  clipboard.AsText := mmpFileNameWithoutExtension(currentItem);
  ST.opInfo := 'Copied to clipboard';
  result := TRUE;
end;

function TPlaylist.count: integer;
begin
  result := FPlaylist.count;
end;

constructor TPlaylist.create;
begin
  inherited;
  FPlaylist := TList<string>.create;
  FPLaylist.sort;
end;

function TPlaylist.currentFolder: string;
begin
  result := FCurrentFolder;
end;

function TPlaylist.currentItem: string;
begin
  result := '';
  case FPlayIx = -1 of TRUE: EXIT; end;
  result := FPlaylist[FPlayIx];
end;

function TPlaylist.currentIx: integer;
begin
  result := FPlayIx;
end;

function TPlaylist.delete(const ix: integer = -1): boolean;
begin
  result := FALSE;
  case hasItems of FALSE: EXIT; end;
  case ix = -1 of  TRUE:  begin
                            FPlaylist.delete(FPlayIx);
                            dec(FPlayIx); end;
                  FALSE:  begin
                            case (ix < 0) or (ix > FPlaylist.count - 1) of TRUE: EXIT; end;
                            FPlaylist.delete(ix);
                            dec(FPlayIx); end;end;

  case (FPlayIx < 0) and (FPlaylist.count > 0) of TRUE: FPlayIx := 0; end; // the item at index 0 was deleted so point to the new item[0]
  result := TRUE;
end;

destructor TPlaylist.Destroy;
begin
  case FPlaylist <> NIL of TRUE: FPlaylist.free; end;
  inherited;
end;

function TPlaylist.displayItem: string;
begin
  result := format('[%d/%d] %s', [FPlayIx, count, extractFileName(currentItem)]);
end;

function TPlaylist.fillPlaylist(const aFolder: string; const aSetOfMediaType: TSetOfMediaType = [mtAudio, mtVideo, mtImage]): boolean;
const
  faFile  = faAnyFile - faDirectory - faHidden - faSysFile;
var
  vSR: TSearchRec;
  vExt: string;

  function fileExtOK: boolean;
  begin
    result := MT.mediaType(vExt) in aSetOfMediaType;
  end;

begin
  result := FALSE;
  clear;
  case directoryExists(aFolder) of FALSE: EXIT; end;
  FCurrentFolder := aFolder;

  case FindFirst(aFolder + '*.*', faFile, vSR) = 0 of  TRUE:
    repeat
      vExt := lowerCase(extractFileExt(vSR.name));
      case fileExtOK of TRUE: add(aFolder + vSR.Name); end;
    until FindNext(vSR) <> 0;
  end;

  system.sysUtils.FindClose(vSR);
  sort;

  case hasItems of  TRUE: FPlayIx := 0;
                   FALSE: FPlayIx := -1; end;

  result := TRUE;
end;

function TPlaylist.find(const anItem: string): boolean;
begin
  FPlayIx := FPlaylist.indexOf(anItem);
  result  := FPlayIx <> -1;
end;

function TPlaylist.first: boolean;
begin
  result := FALSE;
  case hasItems of TRUE: FPlayIx := 0; end;
  result := TRUE;
end;

function TPlaylist.formattedItem: string;
begin
  case hasItems of FALSE: EXIT; end;
  result := format('[%d/%d] %s', [FPlayIx + 1, FPlaylist.count, ExtractFileName(currentItem)]);
end;

function TPlaylist.getPlaylist(aListBox: TListBox): boolean;
var i: integer;
begin
  aListBox.clear;
  for i := 0 to FPlaylist.count - 1 do
    aListBox.items.add(extractFileName(FPlaylist[i]));
end;

function TPlaylist.hasItems: boolean;
begin
  result := FPlaylist.count > 0;
end;

function TPlaylist.indexOf(const anItem: string): integer;
begin
  result := FPlaylist.indexOf(anItem);
end;

function TPlaylist.insert(const anItem: string): boolean;
// insert at FPlayIx + 1, after the current item
begin
  case next of  TRUE: FPlaylist.insert(FPlayIx, anItem);
               FALSE: FPlaylist.add(anItem); end;
end;

function TPlaylist.isFirst: boolean;
begin
  result := FPlayIx = 0;
end;

function TPlaylist.isLast: boolean;
begin
  result := FPlayIx = FPlaylist.count - 1;
end;

function TPlaylist.last: boolean;
begin
  result := FALSE;
  case hasItems of TRUE: FPlayIx := FPlaylist.count - 1; end;
  result := TRUE;
end;

function TPlaylist.next: boolean;
begin
  result := FALSE;
  case hasItems of FALSE: EXIT; end;
  case isLast of TRUE: EXIT; end;
  inc(FPlayIx);
  result := TRUE;
end;

function TPlaylist.prev: boolean;
begin
  result := FALSE;
  case hasItems of FALSE: EXIT; end;
  case isFirst of TRUE: EXIT; end;
  dec(FPlayIx);
  result := TRUE;
end;

function TPlaylist.replaceCurrentItem(const aNewItem: string): boolean;
begin
  result := FALSE;
  case hasItems of FALSE: EXIT; end;
  FPlaylist[FPlayIx] := aNewItem;
  result := TRUE;
end;

function TPlaylist.extractNumericPart(const aString: string): Integer;
var
  vMatch: TMatch;
begin
  // Use a regular expression to extract the numeric part from the string
  vMatch := TRegEx.match(aString, '\d+');
  if vMatch.success then
    result := strToIntDef(vMatch.value, 0)
  else
    result := 0;
end;

function TPlaylist.setIx(const ix: integer): integer;
begin
  case validIx(ix) of  TRUE: FPlayIx := ix;
                      FALSE: first; end;
end;

function TPlaylist.sort: boolean;
begin
  result := FALSE;

  FPlaylist.naturalSort;

  result := TRUE;
end;

function TPlaylist.thisItem(const ix: integer): string;
begin
  result := '';
  case hasItems of FALSE: EXIT; end;
  case (ix < 0) or (ix > FPlaylist.count - 1) of TRUE: EXIT; end;
  result := FPlaylist[ix];
end;

function TPlaylist.validIx(const ix: integer): boolean;
begin
  result := FALSE;
  case hasItems of FALSE: EXIT; end;
  case (ix < 0) or (ix > FPlaylist.count - 1) of TRUE: EXIT; end;
  result := TRUE;
end;

end.

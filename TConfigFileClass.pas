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
unit TConfigFileClass;

interface

uses
  system.classes, system.ioUtils;

type
  TConfigFile = class(TObject)
  strict private
    FFileContents: TStringList;
    FFilePath: string;
    FLastWriteTime: TDateTime;
    function saveConfigFile: boolean;
  private
    function getValue(const aName: string): string;
    procedure setValue(const aName: string; const aValue: string);
    function getAsBoolean(const aName: string): boolean;
    function getAsInteger(const aName: string): integer;
    function checkForManualEdits: boolean;
  public
    constructor create;
    destructor Destroy; override;
    function deleteConfig(const aName: string): boolean;
    function initConfigFile(const aFilePath: string): boolean;
    function toHex(const aInteger: integer): string;
    property asBoolean[const aName: string]: boolean read getAsBoolean;
    property asInteger[const aName: string]: integer read getAsInteger;
    property value[const aName: string]: string read getValue write setValue; default;
  end;


implementation

uses
  system.sysUtils,
  _debugWindow;

{ TConfigFile }

constructor TConfigFile.create;
begin
  inherited;
  FFileContents                 := TStringList.create;
  FFileContents.DefaultEncoding := TEncoding.UTF8;
  FFileContents.CaseSensitive   := FALSE;
end;

function TConfigFile.checkForManualEdits: boolean;
begin
  case fileExists(FFilePath) of FALSE: EXIT; end;

  var vLastWriteTime := TFile.getLastWriteTime(FFilePath);
  case vLastWriteTime > FLastWriteTime of TRUE: begin
                                                  FLastWriteTime := vLastWriteTime;
                                                  FFileContents.loadFromFile(FFilePath);
                                                end;end;
end;

function TConfigFile.deleteConfig(const aName: string): boolean;
begin
  checkForManualEdits;
  var vIx := FFileContents.indexOfName(aName);
  case vIx <> -1 of TRUE: begin
                            FFileContents.delete(vIx);
                            saveConfigFile; end;end;
end;

destructor TConfigFile.Destroy;
begin
  case FFileContents <> NIL of TRUE: FFileContents.free; end;
  inherited;
end;

function TConfigFile.getAsBoolean(const aName: string): boolean;
begin
  checkForManualEdits;
  result := lowerCase(FFileContents.values[aName]) = 'yes';
end;

function TConfigFile.getAsInteger(const aName: string): integer;
begin
  checkForManualEdits;
  try result := strToIntDef(FFileContents.values[aName], 0); except result := 0; end;
end;

function TConfigFile.getValue(const aName: string): string;
begin
  checkForManualEdits;
  result := FFileContents.values[aName];
end;

function TConfigFile.initConfigFile(const aFilePath: string): boolean;
begin
  FFilePath := aFilePath;
end;

function TConfigFile.saveConfigFile: boolean;
begin
  checkForManualEdits;
  try
    FFileContents.saveToFile(FFilePath);
  except // trap rapid-fire write errors, e.g. when user holds down ctrl-B
  end;
end;

procedure TConfigFile.setValue(const aName: string; const aValue: string);
begin
  checkForManualEdits;
  FFileContents.values[aName] := aValue;
  saveConfigFile;
end;

function TConfigFile.toHex(const aInteger: integer): string;
begin
  result := '$' + intToHex(aInteger);
end;

end.

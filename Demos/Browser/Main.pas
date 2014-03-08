unit Main;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  Menus, ActnList, ComCtrls, StdCtrls, ExtCtrls, Buttons;

type
  TMainForm = class(TForm)
    MainMenu1: TMainMenu;
    Browsefolder1: TMenuItem;
    Browsefile1: TMenuItem;
    N1: TMenuItem;
    Exit1: TMenuItem;
    ActionList1: TActionList;
    Action1: TAction;
    edDir: TEdit;
    PaintBox: TPaintBox;
    btnChooseDir: TBitBtn;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure Exit1Click(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure Action1Execute(Sender: TObject);
    procedure PaintBoxPaint(Sender: TObject);
    procedure btnChooseDirClick(Sender: TObject);
  private
    FThumbFrame,
    FThumbOffset,
    FTextHeight: Integer;
    FFileList: TList;
    FSelectedImage,
    FThumbWidth,
    FThumbHeight,
    FLastIndex: Integer;
    FDirectory: String;
    procedure CalculateSize;
    procedure ClearFileList;
    procedure RescaleImage(Source, Target: TBitmap; FastStretch: Boolean);
    procedure CalculateCounts(var XCount, YCount, HeightPerLine, ImageWidth: Integer);
    procedure ReadIniSettings;
    procedure WriteIniSettings;
  public
    { Public declarations }
  end;

var
  MainForm: TMainForm;

//----------------------------------------------------------------------------------------------------------------------

implementation

{$R *.DFM}

uses
  GraphicEx,
  proj_common, IniFiles; // these both just for the SelectDirectory function

type
  PFileEntry = ^TFileEntry;
  TFileEntry = record
    Name: String;
    Bitmap: TBitmap;
  end;

//----------------------------------------------------------------------------------------------------------------------

procedure TMainForm.FormCreate(Sender: TObject);

begin
  // the space to be left between the border and the content in an image (horizontally and vertically)
  FThumbFrame := 2;
  // the space to be left between two adjacent images (horizontally and vertically)
  FThumbOffset := 15;
  // height of the entire text area below each image
  FTextHeight := 15;
  // thumb size
  FThumbWidth := 100;
  FThumbHeight := 100;

  FSelectedImage := -1;
  
  FFileList := TList.Create;
  ReadIniSettings;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TMainForm.CalculateCounts(var XCount, YCount, HeightPerLine, ImageWidth: Integer);

begin
  // How many images per line?
  ImageWidth := FThumbWidth + 2 * (FThumbFrame + 1) + FThumbOffset;
  XCount := Trunc((PaintBox.ClientWidth + FThumbOffset) / ImageWidth);
  if XCount = 0 then XCount := 1;
  // How many (entire) images above the client area?
  HeightPerLine := FThumbHeight + 2 * (FThumbFrame + 1) + FThumbOffset + FTextHeight;
  YCount := Trunc(VertScrollBar.Position / HeightPerLine);
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TMainForm.PaintBoxPaint(Sender: TObject);

var
  XPos,
  YPos,
  Index,
  XCount,
  YCount,
  HeightPerLine,
  ImageWidth,
  EraseTop: Integer;
  R,
  ImageR,
  TextR: TRect;
  S: String;
  ImageData: PFileEntry;

begin
  with PaintBox.Canvas do
  begin
    // calculate and set initial values
    Brush.Color := clBtnHighlight;
    Pen.Width := FThumbFrame;
    Pen.Color := clBtnHighlight;

    CalculateCounts(XCount, YCount, HeightPerLine, ImageWidth);
    // vertical draw offset is then:
    YPos := 5 - VertScrollBar.Position + YCount * HeightPerLine;
    // finally we need the image index to start with
    Index := XCount * YCount;
    // from where to start erasing unfilled parts
    EraseTop := 0;

    // now loop until the client area is filled
    if Index < FFileList.Count then
    repeat
      XPos := (Index mod XCount) * ImageWidth;

      if (FLastIndex = -1) or (Index >= FLastIndex) then
      begin
        // get current image
        ImageData := FFileList[Index];

        // determine needed display area
        R := Rect(XPos, YPos, XPos + FThumbWidth + 2 * (FThumbFrame + 1),
          YPos + FThumbHeight + 2 * (FThumbFrame + 1) + FTextHeight);

        S := ExtractFileName(ImageData.Name);
        TextR := R;
        TextR.Top := TextR.Bottom - FTextHeight;
        OffsetRect(TextR, 0, -(1 + FThumbFrame));
        InflateRect(TextR, -(1 + FThumbFrame), 0);

        // skip images not shown in the client area
        if R.Bottom > 0 then
        begin
          // early out if client area is filled
          if R.Top > PaintBox.Height then Break;

          // fill thumb frame area (frame only to avoid flicker)
          if Index = FSelectedImage then Pen.Color := clBlack
                                    else Pen.Color := clBtnHighlight;
          with R do
            Polyline([Point(Left + 2, Top + 2), Point(Right - 2, Top + 2),
                      Point(Right - 2, Bottom - 2), Point(Left + 2, Bottom - 2),
                      Point(Left + 2, Top + 1)]);

          // draw image centered
          ImageR := Rect(R.Left + 1 + FThumbFrame + (FThumbWidth - ImageData.Bitmap.Width) div 2,
                         R.Top + 1 + FThumbFrame + (FThumbHeight - ImageData.Bitmap.Height) div 2,
                         0, 0);
          ImageR.Right := ImageR.Left + ImageData.Bitmap.Width;
          ImageR.Bottom := ImageR.Top + ImageData.Bitmap.Height;

          Draw(ImageR.Left, ImageR.Top, ImageData.Bitmap);

          with ImageR do
            ExcludeClipRect(Handle, Left, Top, Right, Bottom);

          FillRect(R);

          // a bevel around image and text
          DrawEdge(Handle, R, BDR_SUNKENOUTER, BF_RECT);

          // draw caption
          DrawText(Handle, PChar(ImageData.Name), Length(ImageData.Name), TextR, DT_END_ELLIPSIS or
            DT_SINGLELINE or DT_VCENTER or DT_NOPREFIX);

          with R do
            ExcludeClipRect(Handle, Left, Top, Right, Bottom);
        end;
      end
      else EraseTop := YPos;

      Inc(Index);
      // go to next line if this one is filled
      if (Index mod XCount) = 0 then Inc(YPos, HeightPerLine);
    until (YPos >= Height) or (Index = FFileList.Count);
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TMainForm.ClearFileList;

var
  I: Integer;
  ImageData: PFileEntry;

begin
  for I := 0 to FFileList.Count - 1 do
  begin
    ImageData := FFileList[I];
    ImageData.Bitmap.Free;
    Dispose(ImageData);
  end;
  FFileList.Clear;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TMainForm.FormDestroy(Sender: TObject);

begin
  WriteIniSettings;
  ClearFileList;
  FFileList.Free;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TMainForm.Exit1Click(Sender: TObject);

begin
  Close;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TMainForm.RescaleImage(Source, Target: TBitmap; FastStretch: Boolean);

// if source is in at least one dimension larger than the thumb size then rescale source
// but keep aspect ratio

var
  NewWidth,
  NewHeight: Integer;
  
begin
  if (Source.Width > FThumbWidth) or (Source.Height > FThumbHeight) then
  begin
    // Note: rescaling does only work for 24 bit images hence even monochrom images
    //       are converted to RGB.
    if Source.Width > Source.Height then
    begin
      NewWidth := FThumbWidth;
      NewHeight := Round(FThumbHeight * Source.Height / Source.Width);
    end
    else
    begin
      NewHeight := FThumbHeight;
      NewWidth := Round(FThumbWidth * Source.Width / Source.Height);
    end;
    if FastStretch then
    begin
      Target.PixelFormat := pf24Bit;
      Target.Width := NewWidth;
      Target.Height := NewHeight;
      Target.Palette := Source.Palette;
      SetStretchBltMode(Target.Canvas.Handle, COLORONCOLOR);
      StretchBlt(Target.Canvas.Handle, 0, 0, NewWidth, NewHeight, Source.Canvas.Handle, 0, 0,
                 Source.Width, Source.Height, SRCCOPY);
      //Target.Canvas.CopyRect(Rect(0, 0, NewWidth, NewHeight), Source.Canvas, Rect(0, 0, Source.Width, Source.Height));
    end
    else Stretch(NewWidth, NewHeight, sfTriangle, 0, Source, Target);
  end
  else Target.Assign(Source);
end;

//----------------------------------------------------------------------------------------------------------------------

function Compare(Item1, Item2: Pointer): Integer;

begin
  Result := CompareText(PFileEntry(Item1).Name, PFileEntry(Item2).Name);
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TMainForm.FormResize(Sender: TObject);

begin
  CalculateSize;
  Invalidate;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TMainForm.CalculateSize;

// determines vertical scroll range depending on size of thumbnails and number of images

var
  ImageWidth,
  XCount,
  HeightPerLine: Integer;
begin
  // How many images per line?
  ImageWidth := FThumbWidth + 2 * (FThumbFrame + 1) + FThumbOffset;
  XCount := Trunc((ClientWidth + FThumbOffset) / ImageWidth);
  if XCount = 0 then XCount := 1;
  // How many lines are this?
  HeightPerLine := FThumbHeight + 2 * (FThumbFrame + 1) + FThumbOffset + FTextHeight;
  //VertScrollBar.Range := HeightPerLine * (FFileList.Count div XCount);
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TMainForm.Action1Execute(Sender: TObject);

var
  Picture: TPicture;
  SR: TSearchRec;
  Extensions: TStringList;
  I: Integer;
  Entry: PFileEntry;
  Ext: String;
  Count,
  XCount,
  YCount,
  YPos,
  HeightPerLine,
  ImageWidth: Integer;
  R: TRect;

begin
  FDirectory := edDir.Text;
  Ext := FDirectory;
  // copy current folder to another variable because it is cleared on call of the
  // select function
  if SelectDirectory('Select folder to browse', Ext, '', False, FDirectory) then
  begin
    ClearFileList;
    Count := 0;
    VertScrollBar.Range := 0;

    // precalculations for optimized invalidation
    CalculateCounts(XCount, YCount, HeightPerLine, ImageWidth);
    YPos := 5 - VertScrollBar.Position + YCount * HeightPerLine;
    R := ClientRect;

    if AnsiLastChar(FDirectory)^ <> '\' then FDirectory := FDirectory + '\';
    Picture := TPicture.Create;
    Extensions := TStringList.Create;
    try
      FileFormatList.GetExtensionList(Extensions);
      for I := 0 to Extensions.Count - 1 do Extensions[I] := '.' + UpperCase(Extensions[I]);
      Extensions.Sort;
      if FindFirst(FDirectory + '*.*', faAnyFile, SR) = 0 then
      begin
        // iterate through the picked folder and collect all known image files
        repeat
          if SR.Attr <> faDirectory then
          begin
            // check whether this file is an image file we can show
            Ext := ExtractFileExt(SR.Name);
            if Extensions.Find(Ext, I) then
            begin
              // fine, we found an image file, so add it to our internal list
              New(Entry);
              Entry.Name := SR.Name;
              Entry.Bitmap := TBitmap.Create;
              try
                Picture.LoadFromFile(FDirectory + SR.Name);
                if not (Picture.Graphic is TBitmap) then
                begin
                  // Some extra steps needed to keep non TBitmap descentant alive when scaling.
                  // This is needed because when accessing Picture.Bitmap all non-TBitmap content
                  // will simply be erased (definitly the wrong action, but we can't do anything
                  // to prevent this). Hence we must draw the graphic to a bitmap.
                  with Entry.Bitmap do
                  begin
                    PixelFormat := pf24Bit;
                    Width := Picture.Width;
                    Height := Picture.Height;
                    Canvas.Draw(0, 0, Picture.Graphic);
                  end;
                  Picture.Bitmap.Assign(Entry.Bitmap);
                end;
                RescaleImage(Picture.Bitmap, Entry.Bitmap, True);
                FFileList.Add(Entry);
                Caption := IntToStr(Count) + ' images loaded';
                R.Top := YPos + (Count div XCount) * HeightPerLine;
                if R.Top < R.Bottom then
                begin
                  InvalidateRect(Handle, @R, False);
                  UpdateWindow(Handle);
                end;
                Inc(Count);
              except
                // no exceptions please, just ignore invalid images
                Application.ProcessMessages;
              end;
            end;
          end;
        until FindNext(SR) <> 0;
        FindCLose(SR);
      end;
      CalculateSize;
      FFileList.Sort(Compare);
      Invalidate;
    finally
      Extensions.Free;
      Picture.Free;
      Caption := 'Directory image browser demo program (' + IntToStr(Count) + ' images loaded)';
      FLastIndex := -1;
    end;
  end
  else FDirectory := Ext;
  edDir.Text := FDirectory;
end;

procedure TMainForm.btnChooseDirClick(Sender: TObject);
var
  Ext: String;
begin
  FDirectory := edDir.Text;
  Ext := FDirectory;
  if SelectDirectory('Select folder to browse', Ext, '', False, FDirectory) then
    edDir.Text := FDirectory
  else FDirectory := Ext;
end;

procedure TMainForm.ReadIniSettings;
var
  IniPath: string;
  iniFile: TIniFile;
begin
  IniPath:=ChangeFileExt(AppPath,'.ini');
  iniFile := TIniFile.Create(IniPath);
  edDir.Text:=iniFile.ReadString('Paths','InitDir','');
end;

procedure TMainForm.WriteIniSettings;
var
  IniPath: string;
  iniFile: TIniFile;
begin
  IniPath:=ChangeFileExt(AppPath,'.ini');
  iniFile := TIniFile.Create(IniPath);
  iniFile.WriteString('Paths','InitDir', edDir.Text);
end;

end.


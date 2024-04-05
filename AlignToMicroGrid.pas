// How to use:
// 1) Run script from schematic
// 2) Any unaligned components will be moved on the grid
// 3) A popup message box will appear on completion

// HALT EXECUTION: ctrl + PauseBreak

// TODO:
// - Support all component types

const
  NEWLINECODE = #13#10;
  TEXTBOXINIT = 'Example:' + NEWLINECODE + 'J3' + NEWLINECODE + 'SH1';

var
  SchDoc: ISch_Document;
  WorkSpace: IWorkSpace;
  SchIterator: ISch_Iterator;
  SchIterator2: ISch_Iterator;
  SchComponent: ISch_Component;
  SchComponent2: ISch_Component;
  Location: TLocation;
  GridSize: TCoord;
  LocX, LocY, Len: Integer;
  LabelText: String;

  // Add stubs only to selected components or to all
  OnlySelectedComps: Boolean;
  // By this you can enable if Net Labels will be
  // automatically added to the wire stubs
  AddNetLabels: Boolean;
  // If this value is true Pin Designators are used as
  // Netlabels, for false Pin Names are used
  DesigToLabels: Boolean;

  // Length of wire stub attached to the pin defined by
  // multiple of visible grid
  StubLength: Integer;
  // Top (pin orientation 90°) offset of Net label
  // position defined by multiple of visible grid
  LabelOffsetTop: Integer;
  // Bottom (pin orientation 270°) offset of Net label
  // position defined by multiple of visible grid
  LabelOffsetBot: Integer;
  // Right (pin orientation 0°) offset of Net label
  // position defined by multiple of visible grid
  LabelOffsetRight: Integer;
  // Left (pin orientation 180°) offset of Net label
  // position defined by multiple of visible grid
  LabelOffsetLeft: Integer;

  SilkscreenPositionDelta: TCoord;
  SilkscreenPositionDeltaEx: Single;

const
  // Could not find the correct definition from Altium Script Reference
  PowerPort = 39;
  NoErc = 35;

function Get_Iterator_Count(Iterator: ISch_Iterator): Integer;
var
  cnt: Integer;
  Cmp: ISch_Component;
begin
  cnt := 0;

  Cmp := Iterator.FirstSchObject;
  while Cmp <> nil do
  begin
    Inc(cnt);
    Cmp := Iterator.NextSchObject;
  end;
  Result := cnt;
end;

procedure TfrmAddWireStubs.btnAddStubsClick(Sender: TObject);
begin
  // Read settings from GUI
  OnlySelectedComps := chkOnlySelectedComps.Checked;
  AddNetLabels := chkAddNetlabels.Checked;
  DesigToLabels := chkDesignatorToLabel.Checked;

  StubLength := txtStub.Text;
  if (StubLength < 1) then
  begin
    StubLength := 1;
    txtStub.Text := 1;
  end;

  LabelOffsetTop := txtOffsetTop.Text;
  LabelOffsetBot := txtOffsetBot.Text;
  LabelOffsetRight := txtOffsetRight.Text;
  LabelOffsetLeft := txtOffsetLeft.Text;

  AddWireStubsSchRun;
end;

procedure TfrmAddWireStubs.CancelClick(Sender: TObject);
begin
  close;
end;

procedure TfrmAddWireStubs.btnRemoveClick(Sender: TObject);
begin
  lstIgnore.DeleteSelected();
end;

procedure AddListItem(Dummy: String = '');
begin
  lstIgnore.AddItem(txtIgnore.Text, Nil);
  txtIgnore.Clear;
end;

procedure TfrmAddWireStubs.btnAddClick(Sender: TObject);
begin
  AddListItem;
end;

procedure TfrmAddWireStubs.txtIgnoreKeyPress(Sender: TObject; var Key: Char);
begin
  if Key = #13 then
    AddListItem;
end;

procedure TfrmAddWireStubs.lstIgnoreKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if Key = 46 then
    lstIgnore.DeleteSelected();
end;

procedure RunGUI;
begin
  Form_PlaceSilk.ShowModal;
end;

procedure AddMessage(MessageClass, MessageText: String);
begin
  // https://www.altium.com/ru/documentation/altium-nexus/wsm-api-types-and-constants/#Image%20Index%20Table
  // [!!!] 66 index for debug info
  GetWorkspace.DM_MessagesManager.BeginUpdate();
  GetWorkspace.DM_MessagesManager.AddMessage(MessageClass, MessageText,
    'Auto Place Silkscreen', GetWorkspace.DM_FocusedDocument.DM_FileName, '',
    '', 75, MessageClass = 'APS Status');
  GetWorkspace.DM_MessagesManager.EndUpdate();
  GetWorkspace.DM_MessagesManager.UpdateWindow();
end;

function RoundLocation(L: TLocation): TLocation;
var
  LocX, LocY: Single;
  N: Single;
begin
  N := SilkscreenPositionDeltaEx;
  LocX := CoordToMMs(L.X);
  LocY := CoordToMMs(L.Y);

  LocX := Round(LocX / N) * N;
  LocY := Round(LocY / N) * N;

  L.X := MMsToCoord(LocX);
  L.Y := MMsToCoord(LocY);

  Result := L;
end;

Procedure AddWireStubsSchRun(Dummy: String = '');
var
  componentCount: Integer;
  StartTime: TDateTime;
  Count_, PlaceCnt_: Integer;
  Loc: TLocation;
  LocX, LocY: Integer;
  I, m: Integer;
Begin
  If SchServer = Nil Then
  begin
    ShowMessage('Could not connect to SchServer!');
    Exit;
  end;
  SchDoc := SchServer.GetCurrentSchDocument;
  If SchDoc = Nil Then
  begin
    ShowMessage
      ('No Schematic document found. This script has to be started from an open Schematic Document.');
    Exit;
  end;

  StartTime := Now();

  GetWorkspace.DM_MessagesManager.ClearMessages();
  GetWorkspace.DM_ShowMessageView();

  AddMessage('APD Event', 'Aligning Started');

  // Set cursor to waiting.
  Screen.Cursor := crHourGlass;

  // Initialize the robots in Schematic editor.
  SchServer.ProcessControl.PreProcess(SchDoc, '');

  // Create an iterator to look for components only
  SchIterator := SchDoc.SchIterator_Create;
  // SchIterator.AddFilter_ObjectSet(MkSet(eLine,ePolyline,ePolygon));
  SchIterator.AddFilter_ObjectSet(MkSet(ePolyline));
  // SchIterator.AddFilter_ObjectSet(MkSet(eSchComponent));

  ProgressBar1.Position := 0;
  ProgressBar1.Update;
  ProgressBar1.Max := Get_Iterator_Count(SchIterator);

  GridSize := SchDoc.VisibleGridSize / cInternalPrecision;
  componentCount := 0;

  Count_ := 1;
  PlaceCnt_ := 1;

  Try
    SchComponent := SchIterator.FirstSchObject;
    While SchComponent <> Nil Do
    Begin
      if (OnlySelectedComps = False) OR (SchComponent.Selection = True) then
      Begin
        Inc(componentCount);
        Location := SchComponent.Location;

        LocX := CoordToMMs(Location.X); // Location.X / cInternalPrecision;
        LocY := CoordToMMs(Location.Y); // Location.Y / cInternalPrecision;

        AddMessage('Location', Format('%s = %f , %f',
          [SchComponent.GetState_IdentifierString, (LocX), (LocY)]));

        SchServer.RobotManager.SendMessage(SchComponent.I_ObjectAddress,
          c_BroadCast, SCHM_BeginModify, c_NoEventData);

        SchComponent.Location := RoundLocation(SchComponent.Location);

        for I := 0 to SchComponent.VerticesCount - 1 do
        begin
          Location := SchComponent.Vertex[I + 1];
          LocX := CoordToMMs(Location.X); // Location.X / cInternalPrecision;
          LocY := CoordToMMs(Location.Y); // Location.Y / cInternalPrecision;
          // AddMessage('Location', Format('%s = %f , %f',   ['Vertice',(LocX), (LocY)]));

          SchComponent.Vertex[I + 1] :=
            RoundLocation(SchComponent.Vertex[I + 1]);
        end;
        // Location := Point
        SchServer.RobotManager.SendMessage(SchComponent.I_ObjectAddress,
          c_BroadCast, SCHM_EndModify, c_NoEventData);
      End;
      SchComponent := SchIterator.NextSchObject;

      ProgressBar1.Position := ProgressBar1.Position + 1;
      ProgressBar1.Update;
      {
        AddMessage('APS Status',
        Format('%d of %d silkscreens placed (%f%%) in %d Second(s)',
        [PlaceCnt_, Count_, PlaceCnt_ / Count_ * 100,
        Trunc((Now() - StartTime) * 86400)])); }
    End;
  Finally
    SchDoc.SchIterator_Destroy(SchIterator);
    if (componentCount = 0) then
    begin
      // ShowMessage('No component was selected. Either select the components to add stubs to, or uncheck "Add stubs only on selected Components"');
    end;
  End;


  // for m := eFirstObjectID to eLastObjectId do

  // Create an iterator to look for components only
  SchIterator := SchDoc.SchIterator_Create;
  SchIterator.AddFilter_ObjectSet(MkSet(eLabel));

  ProgressBar1.Position := 0;
  ProgressBar1.Update;
  ProgressBar1.Max := Get_Iterator_Count(SchIterator);

  GridSize := SchDoc.VisibleGridSize / cInternalPrecision;
  componentCount := 0;

  Count_ := 1;
  PlaceCnt_ := 1;

  // AddMessage('From', Format('%d ',   [eFirstObjectID]));
  // AddMessage('To', Format('%d ',   [eLabel]));
  // AddMessage('==============', Format('%d ',   [m]));

  Try
    SchComponent := SchIterator.FirstSchObject;
    While SchComponent <> Nil Do
    Begin
      // AddMessage('Location', Format('%s ',   [SchComponent.GetState_IdentifierString,(LocX), (LocY)]));

      if (OnlySelectedComps = False) OR (SchComponent.Selection = True) then
      Begin
        Inc(componentCount);
        Location := SchComponent.Location;

        LocX := CoordToMMs(Location.X); // Location.X / cInternalPrecision;
        LocY := CoordToMMs(Location.Y); // Location.Y / cInternalPrecision;

        AddMessage('Location', Format('%s = %f , %f',
          [SchComponent.GetState_IdentifierString, (LocX), (LocY)]));

        SchServer.RobotManager.SendMessage(SchComponent.I_ObjectAddress,
          c_BroadCast, SCHM_BeginModify, c_NoEventData);
        SchComponent.Location := RoundLocation(SchComponent.Location);
        SchServer.RobotManager.SendMessage(SchComponent.I_ObjectAddress,
          c_BroadCast, SCHM_EndModify, c_NoEventData);
      End;
      SchComponent := SchIterator.NextSchObject;

      ProgressBar1.Position := ProgressBar1.Position + 1;
      ProgressBar1.Update;
      {
        AddMessage('APS Status',
        Format('%d of %d components aligned (%f%%) in %d Second(s)',
        [PlaceCnt_, Count_, PlaceCnt_ / Count_ * 100,
        Trunc((Now() - StartTime) * 86400)])); }
    End;
  Finally
    SchDoc.SchIterator_Destroy(SchIterator);
    if (componentCount = 0) then
    begin
      // ShowMessage('No component was selected. Either select the components to add stubs to, or uncheck "Add stubs only on selected Components"');
    end;
  End;

  // Create an iterator to look for components only
  SchIterator := SchDoc.SchIterator_Create;
  SchIterator.AddFilter_ObjectSet(MkSet(eTextFrame));

  ProgressBar1.Position := 0;
  ProgressBar1.Update;
  ProgressBar1.Max := Get_Iterator_Count(SchIterator);

  GridSize := SchDoc.VisibleGridSize / cInternalPrecision;
  componentCount := 0;

  Count_ := 1;
  PlaceCnt_ := 1;

  // AddMessage('From', Format('%d ',   [eFirstObjectID]));
  // AddMessage('To', Format('%d ',   [eLabel]));
  // AddMessage('==============', Format('%d ',   [m]));

  Try
    SchComponent := SchIterator.FirstSchObject;
    While SchComponent <> Nil Do
    Begin
      // AddMessage('Location', Format('%s ',   [SchComponent.GetState_IdentifierString,(LocX), (LocY)]));

      if (OnlySelectedComps = False) OR (SchComponent.Selection = True) then
      Begin
        Inc(componentCount);
        Location := SchComponent.Location;

        LocX := CoordToMMs(Location.X); // Location.X / cInternalPrecision;
        LocY := CoordToMMs(Location.Y); // Location.Y / cInternalPrecision;

        AddMessage('Location', Format('%s = %f , %f',
          [SchComponent.GetState_IdentifierString, (LocX), (LocY)]));

        SchServer.RobotManager.SendMessage(SchComponent.I_ObjectAddress,
          c_BroadCast, SCHM_BeginModify, c_NoEventData);
        SchComponent.Location := RoundLocation(SchComponent.Location);
        SchServer.RobotManager.SendMessage(SchComponent.I_ObjectAddress,
          c_BroadCast, SCHM_EndModify, c_NoEventData);
      End;
      SchComponent := SchIterator.NextSchObject;

      ProgressBar1.Position := ProgressBar1.Position + 1;
      ProgressBar1.Update;
      {
        AddMessage('APS Status',
        Format('%d of %d components aligned (%f%%) in %d Second(s)',
        [PlaceCnt_, Count_, PlaceCnt_ / Count_ * 100,
        Trunc((Now() - StartTime) * 86400)])); }
    End;
  Finally
    SchDoc.SchIterator_Destroy(SchIterator);
    if (componentCount = 0) then
    begin
      // ShowMessage('No component was selected. Either select the components to add stubs to, or uncheck "Add stubs only on selected Components"');
    end;
  End;

  SchDoc.GraphicallyInvalidate;

  // SchServer.RobotManager.SendMessage(AnObject.I_ObjectAddress, c_BroadCast, SCHM_BeginModify, c_NoEventData);
  // eWire   : AnObject.Color     := $0000FF; //red color in bgr format         SchServer.RobotManager.SendMessage(AnObject.I_ObjectAddress, c_BroadCast, SCHM_EndModify  , c_NoEventData);

  SchDoc.UpdateDocumentProperties;
  SchDoc.SetState_TitleBlockOn(True);
  SchDoc.SetState_TitleBlockOn(False);

  ResetParameters;
  AddStringParameter('Action', 'Redraw');
  RunProcess('Sch:Zoom');

  // Clean up the robots in Schematic editor
  SchServer.ProcessControl.PostProcess(SchDoc, '');

  // Restore cursor to normal
  Screen.Cursor := crArrow;

  AddMessage('APD Event', Format('Aligning finished in %d Second(s)',
    [Count_ - PlaceCnt_, Trunc((Now() - StartTime) * 86400)]));

  ShowMessage('Script execution complete. ' + IntToStr(PlaceCnt_) + ' out of ' +
    IntToStr(Count_) + ' Aligned. ' + FloatToStr(Round((PlaceCnt_ / Count_) *
    100)) + '%');
End;

procedure Split(Delimiter: Char; Text: TPCBString; ListOfStrings: TStrings);
begin
  ListOfStrings.Clear;
  ListOfStrings.Delimiter := Delimiter;
  ListOfStrings.StrictDelimiter := True; // Requires D2006 or newer.
  ListOfStrings.DelimitedText := Text;
end;

// Unfortunately [rfReplaceAll] keeps throwing errors, so I had to write this function
function RemoveNewLines(Text: TPCBString): TPCBString;
var
  strlen: Integer;
  NewStr: TPCBString;
begin
  strlen := length(Text);
  NewStr := StringReplace(Text, NEWLINECODE, ',', rfReplaceAll);
  while length(NewStr) <> strlen do
  begin
    strlen := length(NewStr);
    NewStr := StringReplace(NewStr, NEWLINECODE, ',', rfReplaceAll);
    NewStr := StringReplace(NewStr, ' ', '', rfReplaceAll);
  end;
  Result := NewStr;
end;

procedure WriteToIniFile(AFileName: String);
var
  IniFile: TIniFile;
begin
  IniFile := TIniFile.Create(AFileName);

  IniFile.WriteInteger('Window', 'Top', Form_PlaceSilk.Top);
  IniFile.WriteInteger('Window', 'Left', Form_PlaceSilk.Left);
  {
    IniFile.WriteInteger('General', 'FilterOptions', RG_Filter.ItemIndex);
    IniFile.WriteInteger('General', 'FailedPlacementOptions',
    RG_Failures.ItemIndex);
    IniFile.WriteBool('General', 'AvoidVias', chkAvoidVias.Checked);
    IniFile.WriteInteger('General', 'RotationStrategy',
    RotationStrategyCb.ItemIndex);
    IniFile.WriteBool('General', 'TryAlteredRotation',
    TryAlteredRotationChk.Checked);
    IniFile.WriteBool('General', 'FixedSizeEnabled', FixedSizeChk.Checked);
    IniFile.WriteString('General', 'FixedSize', FixedSizeEdt.Text);
    IniFile.WriteBool('General', 'FixedWidthEnabled', FixedWidthChk.Checked);
    IniFile.WriteString('General', 'FixedWidth', FixedWidthEdt.Text); }
  IniFile.WriteString('General', 'PositionDelta', PositionDeltaEdt.Text);
  {
    // I know about loops, but...
    IniFile.WriteBool('General', 'Position1', PositionsClb.Checked[0]);
    IniFile.WriteBool('General', 'Position2', PositionsClb.Checked[1]);
    IniFile.WriteBool('General', 'Position3', PositionsClb.Checked[2]);
    IniFile.WriteBool('General', 'Position4', PositionsClb.Checked[3]);
    IniFile.WriteBool('General', 'Position5', PositionsClb.Checked[4]);
    IniFile.WriteBool('General', 'Position6', PositionsClb.Checked[5]);
    IniFile.WriteBool('General', 'Position7', PositionsClb.Checked[6]);
    IniFile.WriteBool('General', 'Position8', PositionsClb.Checked[7]);
  }

  IniFile.Free;
end;

procedure ReadFromIniFile(AFileName: String);
var
  IniFile: TIniFile;
begin
  IniFile := TIniFile.Create(AFileName);

  Form_PlaceSilk.Top := IniFile.ReadInteger('Window', 'Top',
    Form_PlaceSilk.Top);
  Form_PlaceSilk.Left := IniFile.ReadInteger('Window', 'Left',
    Form_PlaceSilk.Left);
  {
    RG_Filter.ItemIndex := IniFile.ReadInteger('General', 'FilterOptions',
    RG_Filter.ItemIndex);
    RG_Failures.ItemIndex := IniFile.ReadInteger('General',
    'FailedPlacementOptions', RG_Failures.ItemIndex);
    chkAvoidVias.Checked := IniFile.ReadBool('General', 'AvoidVias',
    chkAvoidVias.Checked);
    RotationStrategyCb.ItemIndex := IniFile.ReadInteger('General',
    'RotationStrategy', RotationStrategyCb.ItemIndex);
    TryAlteredRotationChk.Checked := IniFile.ReadBool('General',
    'TryAlteredRotation', TryAlteredRotationChk.Checked);
    FixedSizeChk.Checked := IniFile.ReadBool('General', 'FixedSizeEnabled',
    FixedSizeChk.Checked);
    FixedSizeEdt.Text := IniFile.ReadString('General', 'FixedSize',
    FixedSizeEdt.Text);
    FixedWidthChk.Checked := IniFile.ReadBool('General', 'FixedWidthEnabled',
    FixedWidthChk.Checked);
    FixedWidthEdt.Text := IniFile.ReadString('General', 'FixedWidth',
    FixedWidthEdt.Text); }
  PositionDeltaEdt.Text := IniFile.ReadString('General', 'PositionDelta',
    PositionDeltaEdt.Text);
  {
    // I know about loops, but...
    PositionsClb.Checked[0] := IniFile.ReadString('General', 'Position1',
    PositionsClb.Checked[0]);
    PositionsClb.Checked[1] := IniFile.ReadString('General', 'Position2',
    PositionsClb.Checked[1]);
    PositionsClb.Checked[2] := IniFile.ReadString('General', 'Position3',
    PositionsClb.Checked[2]);
    PositionsClb.Checked[3] := IniFile.ReadString('General', 'Position4',
    PositionsClb.Checked[3]);
    PositionsClb.Checked[4] := IniFile.ReadString('General', 'Position5',
    PositionsClb.Checked[4]);
    PositionsClb.Checked[5] := IniFile.ReadString('General', 'Position6',
    PositionsClb.Checked[5]);
    PositionsClb.Checked[6] := IniFile.ReadString('General', 'Position7',
    PositionsClb.Checked[6]);
    PositionsClb.Checked[7] := IniFile.ReadString('General', 'Position8',
    PositionsClb.Checked[7]);
  }
  IniFile.Free;
end;

function ConfigFilename(Dummy: String = ''): String;
begin
  Result := ClientAPI_SpecialFolder_AltiumApplicationData +
    '\AlignToMicroGrid.ini'
end;

procedure TForm_PlaceSilk.BTN_RunClick(Sender: TObject);
var
  Place_Selected: Boolean;
  Place_OverComp: Boolean;
  Place_RestoreOriginal: Boolean;
  StrNoSpace: TPCBString;
  I: Integer;
  DisplayUnit: TUnit;
  tmpx, tmpy, s: String;
begin
  HintLbl.Visible := True;
  HintLbl.Update;

  // MechLayerIDList.Free;

  // Place_Selected := RG_Filter.ItemIndex = 1;
  // Place_OverComp := RG_Failures.ItemIndex = 0;
  // Place_RestoreOriginal := RG_Failures.ItemIndex = 2;

  // AvoidVias := chkAvoidVias.Checked;

  DisplayUnit := eMM; // Board.DisplayUnit;
  StringToCoordUnit(PositionDeltaEdt.Text, SilkscreenPositionDelta,
    DisplayUnit);
  tmpy := PositionDeltaEdt.Text + '';

  s := StringReplace(tmpy, '.', ',', rfReplaceAll);

  SilkscreenPositionDeltaEx := StrToFloat(s);
  {
    DisplayUnit := Board.DisplayUnit;
    StringToCoordUnit(FixedSizeEdt.Text, SilkscreenFixedSize, DisplayUnit);

    DisplayUnit := Board.DisplayUnit;
    StringToCoordUnit(FixedWidthEdt.Text, SilkscreenFixedWidth, DisplayUnit);

    SilkscreenIsFixedSize := FixedSizeChk.Checked;
    SilkscreenIsFixedWidth := FixedWidthChk.Checked;

    if TryAlteredRotationChk.Checked then
    TryAlteredRotation := 1
    else
    TryAlteredRotation := 0;
  }
  // Main(Place_Selected, Place_OverComp, Place_RestoreOriginal, AllowUnderList);
  AddWireStubsSchRun;

  // AllowUnderList.Free;

  HintLbl.Visible := False;
  HintLbl.Update;

  close;
end;

procedure TForm_PlaceSilk.Form_PlaceSilkCreate(Sender: TObject);
const
  DEFAULT_CMP_OUTLINE_LAYER = 'Mechanical 13';
var
  MechIterator: IPCB_LayerObjectIterator;
  LayerObj: IPCB_LayerObject;
  idx: Integer;
begin
  // Retrieve the current board
  {
    Board := PCBServer.GetCurrentPCBBoard;
    if Board = nil then
    Exit;

    MechLayerIDList := TStringList.Create;

    idx := 0;
    CmpOutlineLayerID := 0;
    MechIterator := Board.MechanicalLayerIterator;
    while MechIterator.Next do
    begin
    LayerObj := MechIterator.LayerObject;

    cbCmpOutlineLayer.AddItem(LayerObj.Name, LayerObj);
    MechLayerIDList.Add(IntToStr(LayerObj.V6_LayerID));

    // Set default layer
    if (LayerObj.Name = DEFAULT_CMP_OUTLINE_LAYER) or
    (ContainsText(LayerObj.Name, 'Component Outline')) then
    begin
    cbCmpOutlineLayer.SetItemIndex(idx);
    CmpOutlineLayerID := LayerObj.V6_LayerID;
    end;

    Inc(idx)
    end;

    RotationStrategy := RotationStrategyCb.GetItemIndex();
  }
  {
    PositionsClb.Items.Clear;

    PositionsClb.Items.AddObject('TopCenter', eAutoPos_TopCenter);
    PositionsClb.Items.AddObject('CenterRight', eAutoPos_CenterRight);
    PositionsClb.Items.AddObject('BottomCenter', eAutoPos_BottomCenter);
    PositionsClb.Items.AddObject('CenterLeft', eAutoPos_CenterLeft);
    PositionsClb.Items.AddObject('TopLeft', eAutoPos_TopLeft);
    PositionsClb.Items.AddObject('TopRight', eAutoPos_TopRight);
    PositionsClb.Items.AddObject('BottomLeft', eAutoPos_BottomLeft);
    PositionsClb.Items.AddObject('BottomRight', eAutoPos_BottomRight);

    PositionsClb.Checked[0] := True;
    PositionsClb.Checked[1] := True;
    PositionsClb.Checked[2] := True;
    PositionsClb.Checked[3] := True;
  }
  // FormCheckListBox1 := PositionsClb;

  HintLbl.Left := (Form_PlaceSilk.ClientWidth - HintLbl.Width) div 2;

  ReadFromIniFile(ConfigFilename);
end;

procedure TForm_PlaceSilk.Form_PlaceSilkClose(Sender: TObject;
  var Action: TCloseAction);
begin
  WriteToIniFile(ConfigFilename);
end;
